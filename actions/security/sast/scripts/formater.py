import sys
from tabulate import tabulate

def read_data_from_file(filename):
    with open(filename, 'r') as file:
        lines = file.readlines()
        # Remove newlines and split data into list of lists
        data = [line.strip().split(',') for line in lines]
    return data

def main():
    if len(sys.argv) != 3:
        print("Usage: python script_name.py <input_filename> <output_filename>")
        return

    input_filename = sys.argv[1]
    output_filename = sys.argv[2]

    input_data = read_data_from_file(input_filename)
    headers = input_data[0]
    # Convert input data to Markdown format
    markdown_table = tabulate(input_data[1:], headers=headers, tablefmt='pipe')

    # Write Markdown table to output file
    with open(output_filename, 'w') as output_file:
        output_file.write(markdown_table)

if __name__ == "__main__":
    main()