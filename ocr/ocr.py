import re
import PIL
import PIL.ImageOps
import pytesseract


class InterestArea:

    def __init__(self, name, coordinates, check_text):
        self.name = name
        self.coordinates = coordinates
        self.check_text = check_text

    def process(self, text):
        regex = f'.*{self.check_text}.*?(\d+)'
        pattern = re.compile(regex)
        match = pattern.match(text)
        if match:
            self.value = int(match.groups()[0])


def extract(filename):
    interest_areas = (
        InterestArea('monitorados', (82, 220, 446, 290), 'MONITORADOS'),
        InterestArea('suspeitos', (504, 220, 868, 290), 'SUSPEITOS'),
        InterestArea('descartados', (106, 350, 456, 412), 'DESCARTADOS'),
        InterestArea('suspeitos_isolados', (504, 294, 874, 356), 'ISOLADOS'),
        InterestArea('suspeitos_internados', (502, 374, 868, 444), 'INTERNADOS'),
        InterestArea('confirmados', (86, 480, 446, 542), 'CONFIRMADOS'),
        InterestArea('confirmados_recuperados', (104, 554, 446, 614), 'RECUPERADOS'),
        InterestArea('confirmados_isolados', (86, 630, 450, 696), 'ISOLADOS'),
        InterestArea('confirmados_internados', (502, 374, 868, 444), 'INTERNADOS')
    )

    image = PIL.Image.open(filename)
    image = PIL.ImageOps.grayscale(image)
    image = PIL.ImageOps.autocontrast(image)
    image = PIL.ImageOps.invert(image)

    for area in interest_areas:
        cropped = image.crop(area.coordinates)
        cropped.load()
        cropped.save(area.check_text + '.jpg', "JPEG")
        data = pytesseract.image_to_string(cropped)
        area.process(data)
        print(f'{area.name}: {area.value}')

    return interest_areas


extract('ocr/boletim2.jpg')
