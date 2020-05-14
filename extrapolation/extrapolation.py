"""
extrapolation.

Usage:
    extrapolation <data_file>
"""

import docopt
import numpy

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


def extrapolate(data_file):
    with open(data_file, 'r') as df:
        dtype = dtypes.get(data_file.split('/')[-1])

        if dtype:
            converters = { i: lambda x: x or 0 for i in range(len(dtype))}
        else:
            converters = 0

        data = numpy.loadtxt(df, dtype=dtype, delimiter=',', skiprows=1, converters=converters)


if __name__ == "__main__":
    args = docopt.docopt(__doc__)
    extrapolate(args['<data_file>'])
