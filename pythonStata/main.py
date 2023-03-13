#!/usr/bin/python

import sys
import duckdb
from itertools import product
import warnings
import pandas as pd
import os
import subprocess
import argparse


def to_list(func):
    def wrapper(*args, **kwargs):
        return list(func(*args, **kwargs))
    return wrapper


def validate_fields(field_list: list[str], all_cols: list[str]):
    valid_fields = [field for field in field_list if field in all_cols]
    invalid_fields = [field for field in field_list if field not in all_cols]
    if invalid_fields:
        warnings.warn("Some fields specified were not available in the database", UserWarning)
    return valid_fields


class MyDB(object):
    """Instance of DuckDB database, will safely close when finished"""

    def __init__(self, db_name):
        self._db_connection = duckdb.connect(database=db_name, read_only=True)

    def __del__(self):
        self._db_connection.close()

    def query(self, query: str, params: list = None):
        """Query the database and return a pandas dataframe"""
        if params is None:
            return self._db_connection.execute(query).fetch_df()
        else:
            return self._db_connection.execute(query, params).fetch_df()

    def col_names(self, tblname: str) -> list[str]:
        """Return a list of all column names in the table"""
        query = "SELECT column_name FROM INFORMATION_SCHEMA.COLUMNS WHERE "
        query += "table_name = '{}';".format(tblname)

        cols = self.query(query)['column_name'].values.tolist()
        return cols

    def get_tables(self) -> list[str]:
        tbls = self._db_connection.execute("SELECT table_name FROM information_schema.tables;").fetchall()
        return list(tbls)


class DoFile:
    """Read and manipulate the Stata do-file generated by ukbconv"""
    # Private: To be written into a do file and applied in Stata post-processing
    _dct_names: list[str]  # Names for variables
    _labels: list[str]  # Labels for levels of categorical variables
    _body: list[str]  # Body of the do file
    # Public:
    all_names: object  # Mapping from database column names to Stata variable identifiers

    def __init__(self, data_cols: pd.Series,
                 do_file: str,
                 dct_file: str):
        # Format list of all columns in current data extract, swap . to _ and remove the "f"
        field_names = [x.replace(".", "_").replace("f", "") for x in data_cols]

        # The stata dct file is a dictionary of variable IDs to names, types and formats
        with open(dct_file) as f:
            dictionary = f.readlines()
        # Keep the rows relevant to the fields in the data extract
        dictionary = [row.replace("\n", "") for row in dictionary if any(f in row for f in field_names)]
        # We want a mapping
        dct_names = {f.split("\t")[1]: f.split("\t")[3] for f in dictionary}
        # Prepare the commands to label variables
        self._dct_names = [f'label variable {key} {dct_names[key]}' for key in dct_names]
        # Prepare mapping from f. names to stata names
        self.all_names = {f'f.{name.replace("_", ".").split(".", 1)[1]}': name for name in dct_names.keys()}

        # The stata do file contains the commands to format the data appropriately
        with open(do_file) as f:
            content = f.readlines()
        # Keep the rows relevant to the fields in the data extract
        content = [row.replace("\n", "") for row in content]
        relevant_content = [row for row in content if any(f in row for f in field_names)]
        # The labels are defined before the main body of commands
        body_text = [row for row in relevant_content if not row.startswith("label define")]
        self._body = [row.replace("DMY", "YMD") if row.startswith("gen double") else row for row in body_text]

        # Identify which labels are required
        m_list = [t for row in self._body for t in row.split() if t.startswith('m_')]
        self._labels = [row for row in content if row.startswith("label define") and any(m in row for m in m_list)]

    def write_do_file(self, out_do: str = "test.do", out_data: str = "test.dta"):
        with open(out_do, "w") as out:
            out.write(f'use "{out_data}"\n')
            out.write("\n".join(self._dct_names))
            out.write("\n")
            out.write("\n".join(self._labels))
            out.write("\n")
            out.write("\n".join(self._body))
            out.write("\nsave, replace")


class Fields:
    """Various generators for a list of fields to extract"""
    field_list: list[str]

    def __init__(self, field_list):
        if "f.eid" not in field_list:
            field_list = ["f.eid"] + field_list
        self.field_list = field_list

    @classmethod
    def spec_max_measure(cls, field_list: list[str], all_cols: list[str]):
        """Specify fields in form f.12345.0.3 to get f.12345.0.0, f.12345.0.1, f.12345.0.2, f.12345.0.3"""

        def instance_split(a):
            """Split field name into field ID (f.XXX), number of instances, number of measures"""
            split = a.split(".")
            return ".".join(split[:2]), int(split[2])+1, int(split[3])+1  # Add one because of zero indexing

        @to_list
        def field_generator(field_list):
            for f in field_list:
                if f == "f.eid":
                    continue
                (field, instances, measures) = instance_split(f)
                yield from (f'{field}.{i}.{m}' for (i, m) in product(range(instances), range(measures)))

        expanded_fields = field_generator(field_list)
        valid_fields = validate_fields(expanded_fields, all_cols)

        return Fields(valid_fields)

    @classmethod
    def spec_prefix(cls, field_list: list[str], all_cols: list[str]):
        """Specify prefixes and return all fields that start with those prefixes, """

        all_fields = [c for c, f in product(all_cols, field_list) if c.startswith(f)]

        return Fields(all_fields)

    @classmethod
    def category_fields(cls, categories: list[int], all_cols: list[str],
                        cat_hierarchy: str = os.path.join(sys.path[0], "catbrowse.csv"),
                        field_file: str = os.path.join(sys.path[0], "UKB_fields.csv")):
        fields = pd.read_csv(field_file)
        hierarchy = pd.read_csv(cat_hierarchy)

        categories = pd.Series(categories)
        children = categories
        while children.isin(hierarchy.parent_id).any():
            children = hierarchy.child_id[hierarchy.parent_id.isin(children)]
            categories = categories.append(children)

        fields = fields[fields.main_category.isin(categories)]
        id_list = fields.field_id.tolist()
        field_list = [col for col, fid in product(all_cols, id_list) if col.startswith(f'f.{fid}.')]

        return Fields(field_list)

    @classmethod
    def flexible_creation(cls, request_list: list[str], all_cols: list[str]):
        all_fields = []

        categories = [int(x) for x in request_list if not x.startswith("f.")]
        if categories:
            cat_fields = Fields.category_fields(categories, all_cols)
            all_fields.extend(cat_fields.field_list)

        field_prefixes = [x for x in request_list if x.startswith("f.") and x.endswith(".")]
        if field_prefixes:
            pre_fields = Fields.spec_prefix(field_prefixes, all_cols)
            all_fields.extend(pre_fields.field_list)

        field_max = [x for x in request_list if x.startswith("f") and not x.endswith(".")]
        if field_max:
            max_fields = Fields.spec_max_measure(field_max, all_cols)
            all_fields.extend(max_fields.field_list)

        unique_fields = list(set(all_fields))
        return Fields(unique_fields)

    def write_query(self, tblname: str = "ukbXXXXX", max_cols: int = 1000,
                    field_file: str = os.path.join(sys.path[0], "UKB_fields.csv")) -> list[str]:
        """Arrange the field names into a query to select those fields from the given table"""
        if len(self.field_list) < max_cols:
            sorted_fields = sorted(self.field_list)
            return ['SELECT "' + '", "'.join(sorted_fields) + '" FROM ' + tblname + ';']
        else:
            self.field_list.remove("f.eid")
            field_ids = set([int(x.split(".")[1]) for x in self.field_list])

            all_fields = pd.read_csv(field_file)
            all_fields = all_fields.query('field_id in @field_ids')

            fields_cat = []
            for category in set(all_fields.main_category):
                category_fields = all_fields.query('main_category == @category')

                intersect_ids = field_ids.intersection(set(category_fields['field_id']))
                intersect_fields = [col for col, fid in product(self.field_list, intersect_ids)
                                    if col.startswith(f'f.{fid}.')]
                fields_cat.append(intersect_fields)

            x = iter(fields_cat)
            grouped = []
            y = []
            while (z := next(x, None)) is not None:
                if len(y + z) < max_cols:
                    y = y + z
                else:
                    grouped.append(y)
                    y = z
            else:
                grouped.append(y)

            print(f'Data contains {len(self.field_list)} columns, '
                  f'splitting into {len(grouped)} output files of at most {max_cols} columns each')

            sorted_fields = [["f.eid"] + sorted(f) for f in grouped]
            queries = ['SELECT "' + '", "'.join(f) + '" FROM ' + tblname + ';' for f in sorted_fields]
            return queries


def read_fields(filepath: str) -> list[str]:
    my_file = open(filepath, "r")
    fields = [x.replace("\n", "") for x in my_file.readlines()]
    # Remove any stray tabs left from copying fields from Excel
    fields = [x.replace("\t", "") for x in fields]
    # If fields have been given in stata n_1234_0_0 format, convert to f.1234.0.0
    fields = [x.replace("_", ".") for x in fields]
    fields = [f'f.{x.split(".", 1)[1]}' if "." in x else x for x in fields]
    return fields


def main(field_list: str = "fields.txt",
         out_file: str = "test.dta",
         out_do: str = "test.do",
         max_cols: int = 1000,
         db_name: str = "ukb_data.db",
         tblname: str = "ukbXXXXX",
         do_file: str = "ukbXXXXX.do",
         dct_file: str = "ukbXXXXX.dct"):
    db = MyDB(db_name=db_name)
    all_cols = db.col_names(tblname=tblname)

    field_list = read_fields(field_list)
    field_obj = Fields.flexible_creation(field_list, all_cols)

    queries: list[str] = field_obj.write_query(tblname=tblname, max_cols=max_cols)
    n = len(queries)
    i = 1 if n > 1 else 0
    for query in queries:
        # Extract data
        data = db.query(query)
        # Drop any completely empty columns
        data.dropna(axis="columns", how="all", inplace=True)
        # Convert category columns to numeric
        data = data.apply(pd.to_numeric, errors='ignore')

        # Map columns to stata names and prepare do file for stata formatting
        do = DoFile(data.columns, do_file=do_file, dct_file=dct_file)
        data.rename(columns=do.all_names, inplace=True)

        if i == 0:
            data.to_stata(path=out_file)
            do.write_do_file(out_do=out_do, out_data=out_file)

            cmd = ["C:/Program Files/Stata17/StataMP-64.exe", "/e", "run", out_do]
            subprocess.call(cmd, shell=True)
        else:
            name, ext = (out_file.split("."))
            outfile_name = f'{name}{i}.{ext}'
            data.to_stata(path=outfile_name)

            name, ext = (out_do.split("."))
            outdo_name = f'{name}{i}.{ext}'
            do.write_do_file(out_do=outdo_name, out_data=outfile_name)

            print(f'Written file {i} of {n}')

            cmd = ["C:/Program Files/Stata17/StataMP-64.exe", "/e", "run", outdo_name]
            subprocess.call(cmd, shell=True)

            print(f'Formatted file {i} of {n}')
            i += 1


if __name__ == "__main__":

    parser = argparse.ArgumentParser(prog='extract_data',
                                    usage='%(prog)s [options] path',
                                    description='List the content of a folder')
    parser.add_argument('field_list', type=str,
                        help='Path to text file containing list of field specifications, one per line')
    parser.add_argument('out_file', type=str,
                        help='Desired output .dta file')
    parser.add_argument('out_do', type=str,
                        help='Desired path to helper .do file that will format the data in Stata style')
    parser.add_argument('max_cols', type=int,
                        help='Maximum number of columns per data file, to avoid running out of memory',
                        default=1000)
    parser.add_argument('db_name', type=str,
                        help='Path to database from which to extract data',
                        default="ukb_data.db")
    parser.add_argument('tblname', type=str,
                        help='Name of table in database',
                        default='ukbXXXXX')
    parser.add_argument('do_file', type=str,
                        help='Path to the .do file generated by ukbconv for the data download',
                        default="ukbXXXXX.do")
    parser.add_argument('dct_file', type=str,
                        help='Path to the .dct file generated by ukbconv for the data download',
                        default="ukbXXXXX.dct")
    args = parser.parse_args()

    main(field_list=args.field_list,
         out_file=args.out_file, out_do=args.out_do,
         max_cols=int(args.max_cols),
         db_name=args.db_name, tblname=args.tblname,
         do_file=args.do_file, dct_file=args.dct_file)

# Command to use in Stata
# python script "C:/Users/jenniferco/My Documents/pythonStata/main.py", args("K:/TEU/UKB33952_Data/Data_Downloads/V5_database_duckdb0.3.0/ukb_v5.db" "ukb48850" "C:/Users/jenniferco/My Documents/pythonStata/fields.txt" "C:/Users/jenniferco/My Documents/pythonStata/test.dta")
