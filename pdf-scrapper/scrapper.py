import PyPDF2
import csv
import os
import os.path
import re
import sys

def extract_text(pdf_filename):
    text = ''

    with open(pdf_filename, 'rb') as f:
        reader = PyPDF2.PdfFileReader(f)

        for p in range(reader.numPages):
            page = reader.getPage(p)
            text += page.extractText()

    return text


def extract_data(text):
    regex = {
        'tracked': '\n(.+)\nmonitorados',
        'discarded': '\n(.+)\ndescartados',
        'confirmed': '\n(.+)\nconfirmados',
        'confirmed_in_infirmary': '\n(.+)\ninternados em',
        'confirmed_in_intensive_care': '\n(.+)\ninternados em',
        'confirmed_deaths': '\n(.+)\nóbitos',
        'confirmed_home_isolation': '\n(.+)\nisolamento',
        'confirmed_recovered': '\n(.+)\nrecuperados',
        'suspected': '\n(.+)\nsuspeitos',
        'suspected_in_infirmary': '\n(.+)\ninternados em',
        'suspected_in_intensive_care': '\n(.+)\ninternados em',
        'suspected_deaths': '\n(.+)\nÓbitos',
        'suspected_home_isolation': '\n(.+)\nisolamento',
    }

    results = {}

    search_from = 0

    for name, pattern in regex.items():
        m = re.search(pattern, text[search_from:], flags = re.IGNORECASE | re.MULTILINE)

        if m:
            results[name] = m.groups()[0].replace('.','')
            search_from += m.span()[1]

    return results


def convert(value):
    try:
        converted = int(value)
    except ValueError as e:
        print(f'warning parsing value: {e}')
        converted = 0

    return converted


def write_csv(data, output):
    headers = sorted(list(data[0].keys()))

    with open(output, 'w+') as f:
        writer = csv.writer(f)

        writer.writerow(headers)

        for entry in data:
            writer.writerow([convert(entry.get(h, 0)) for h in headers])


def process_files(input_directory, output_csv):
    pdf_files = sorted([f for f in os.listdir(input_directory) if f.endswith('.pdf')])

    data = []

    for pdf_file in pdf_files:
        text = extract_text(os.path.join(input_directory, pdf_file))
        data.append(extract_data(text))

    write_csv(data, output_csv)


if __name__ == '__main__':
    process_files(sys.argv[1], sys.argv[2])
