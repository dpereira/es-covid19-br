import PyPDF2
import csv
import datetime
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


def extract_data(text, pdf_filename):
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

    date_separtor_index = pdf_filename.find('_')
    date = pdf_filename[:date_separtor_index]
    parsed_date = datetime.datetime.strptime(date, '%d%m%Y')
    
    results = {
        'date': parsed_date.strftime('%Y-%m-%d')
    }

    search_from = 0

    for name, pattern in regex.items():
        m = re.search(pattern, text[search_from:], flags = re.IGNORECASE | re.MULTILINE)

        if m:
            results[name] = convert(m.groups()[0].replace('.', ''))
            search_from += m.span()[1]


    enhance(results)

    return results


def enhance(results):
    try:
        results['active'] = results['confirmed'] - results['confirmed_recovered']
    except KeyError:
        results['active'] = 0


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
            writer.writerow([entry.get(h, '') for h in headers])


def process_files(input_directory, output_csv):
    pdf_files = sorted([f for f in os.listdir(input_directory) if f.endswith('.pdf')])

    data = []

    for pdf_file in pdf_files:
        text = extract_text(os.path.join(input_directory, pdf_file))
        data.append(extract_data(text, pdf_file))

    write_csv(data, output_csv)


if __name__ == '__main__':
    process_files(sys.argv[1], sys.argv[2])
