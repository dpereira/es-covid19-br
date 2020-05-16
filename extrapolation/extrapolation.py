import argparse
import csv
import datetime
import numpy
import sys

dtypes = {
    'caso.csv': [
        ('date', 'U10'),
        ('state', 'U2'),
        ('city', 'S128'),
        ('place_type','U8'),
        ('confirmed', int),
        ('deaths', int),
        ('order_for_place', int),
        ('is_last', 'U5'),
        ('estimated_population_2019', int),
        ('city_ibge_code', int),
        ('confirmed_per_100k_inhabitants', 'U32'),
        ('death_rate', 'U32')
    ]
}


def cities_data(data):
    sorted_data = numpy.sort(data, order=('city', 'state'))

    current_city = sorted_data[0]['city']
    current_index = 0

    for i, entry in enumerate(sorted_data):
        if  current_city != entry['city']:
            yield sorted_data[current_index:i]
            current_index = i
            current_city = entry['city']


def load_data(input):
    with open(input, 'r') as df:
        dtype = dtypes.get(input.split('/')[-1])

        if dtype:
            converters = { i: lambda x: x or 0 for i in range(len(dtype))}
        else:
            converters = 0

        return numpy.loadtxt(df, dtype=dtype, delimiter=',', skiprows=1, converters=converters)


def extrapolate_data(city_data, field='confirmed', prior=5, after=14):
    daystamps = [
        int(datetime.datetime.strptime(day['date'], '%Y-%m-%d').timestamp() / (24 * 3600))
        for day in city_data
    ]

    prior_index = min(len(city_data[field]), prior)
    fit = numpy.polyfit(daystamps[-prior_index:], city_data[field][-prior_index:], 1)
    p = numpy.poly1d(fit)

    latest_date = max(daystamps)
    extra_data = [max(0, int(p(latest_date + i))) for i in range(1, after + 1)]
    utc_timestamp = lambda i: ((latest_date + i) * 24 * 3600) + 10800  # BRT +3h = UTC
    extra_days = [datetime.datetime.fromtimestamp(utc_timestamp(i)).strftime('%Y-%m-%d') for  i in range(1, after + 1)]

    return extra_days, extra_data


def extrapolate(data, prior=5, after=14):

    extrapolated = []

    for city_data in cities_data(data):
        state = city_data[0]['state']
        city = city_data[0]['city']
        place_type = city_data[0]['place_type']
        order_for_place = city_data[0]['order_for_place']
        estimated_population_2019 = city_data[0]['estimated_population_2019'] or 1
        city_ibge_code = city_data[0]['city_ibge_code']
        is_last = False
        extrapolation = True

        days, confirmed = extrapolate_data(city_data, field='confirmed', prior=prior, after=after)
        days, deaths = extrapolate_data(city_data, field='deaths', prior=prior, after=after)

        data = [
            (
                days[i], state, city.decode('latin-1'), place_type, confirmed[i], deaths[i], order_for_place,
                is_last, estimated_population_2019, city_ibge_code,
                confirmed[i] / (estimated_population_2019 / 100000), deaths[i] / confirmed[i] if confirmed[i] else 0
            )
            for i in range(after)
        ]

        extrapolated += data

    return extrapolated


def save(data, header_names, file_name):

    with open(file_name, 'w+') as f:
        writer = csv.writer(f)

        writer.writerow(header_names)
        for row in data:
            writer.writerow(row)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Extrapolate covid-19 data')
    parser.add_argument('input')
    parser.add_argument('output')
    parser.add_argument('--prior', type=int, default=14)
    parser.add_argument('--after', type=int, default=14)

    args = parser.parse_args()

    data = load_data(args.input)
    e = extrapolate(data, args.prior, args.after)
    save(e, data.dtype.names, args.output)
