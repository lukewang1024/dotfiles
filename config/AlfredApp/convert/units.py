#!/usr/bin/python3
"""Unit registry for the `conv` workflow.

Every dimension declares a base unit; each unit is a multiplier onto that base.
Temperature is the one exception — it is affine, not linear, so those units carry
a conversion pair instead of a factor.

Pinned to system python 3.9 semantics: no 3.10+ syntax.
"""

# --- dimension tables ---------------------------------------------------------
#
# Each entry:  canonical -> (factor onto the dimension's base unit, [aliases])
#
# `companions` is what a bare `conv 10 km` (no target) expands to: the handful of
# units a human actually wants to see side by side for that dimension.

DIMENSIONS = {
    "length": {
        "base": "m",
        "companions": ["m", "km", "ft", "mi"],
        "units": {
            "nm": (1e-9, ["nanometer", "nanometre"]),
            "um": (1e-6, ["µm", "micron", "micrometer", "micrometre"]),
            "mm": (1e-3, ["millimeter", "millimetre"]),
            "cm": (1e-2, ["centimeter", "centimetre"]),
            "m": (1.0, ["meter", "metre", "meters", "metres"]),
            "km": (1e3, ["kilometer", "kilometre", "kilometers", "kilometres"]),
            "in": (0.0254, ["inch", "inches", '"']),
            "ft": (0.3048, ["foot", "feet", "'"]),
            "yd": (0.9144, ["yard", "yards"]),
            "mi": (1609.344, ["mile", "miles"]),
            "nmi": (1852.0, ["nauticalmile", "nm-nautical"]),
        },
    },
    "mass": {
        "base": "kg",
        "companions": ["kg", "g", "lb", "oz"],
        "units": {
            "mg": (1e-6, ["milligram", "milligrams"]),
            "g": (1e-3, ["gram", "grams"]),
            "kg": (1.0, ["kilogram", "kilograms", "kilo", "kilos"]),
            "t": (1e3, ["tonne", "tonnes", "metricton"]),
            "oz": (0.028349523125, ["ounce", "ounces"]),
            "lb": (0.45359237, ["lbs", "pound", "pounds"]),
            "st": (6.35029318, ["stone", "stones"]),
        },
    },
    "volume": {
        "base": "l",
        "companions": ["l", "ml", "gal", "floz"],
        "units": {
            "ml": (1e-3, ["milliliter", "millilitre"]),
            "cl": (1e-2, ["centiliter", "centilitre"]),
            "l": (1.0, ["liter", "litre", "liters", "litres"]),
            "m3": (1e3, ["m^3", "cubicmeter", "cubicmetre"]),
            "tsp": (0.00492892159375, ["teaspoon", "teaspoons"]),
            "tbsp": (0.01478676478125, ["tablespoon", "tablespoons"]),
            "floz": (0.0295735295625, ["fl-oz", "fluidounce"]),
            "cup": (0.2365882365, ["cups"]),
            "pt": (0.473176473, ["pint", "pints"]),
            "qt": (0.946352946, ["quart", "quarts"]),
            "gal": (3.785411784, ["gallon", "gallons"]),
            "impgal": (4.54609, ["imperialgallon", "ukgal"]),
        },
    },
    "area": {
        "base": "m2",
        "companions": ["m2", "ft2", "ha", "acre"],
        "units": {
            "mm2": (1e-6, ["mm^2"]),
            "cm2": (1e-4, ["cm^2"]),
            "m2": (1.0, ["m^2", "sqm", "squaremeter", "squaremetre"]),
            "km2": (1e6, ["km^2", "sqkm"]),
            "ha": (1e4, ["hectare", "hectares"]),
            "in2": (0.00064516, ["in^2", "sqin"]),
            "ft2": (0.09290304, ["ft^2", "sqft", "squarefoot", "squarefeet"]),
            "yd2": (0.83612736, ["yd^2", "sqyd"]),
            "acre": (4046.8564224, ["acres", "ac"]),
            "mi2": (2589988.110336, ["mi^2", "sqmi"]),
        },
    },
    "speed": {
        "base": "m/s",
        "companions": ["km/h", "mph", "m/s", "kn"],
        "units": {
            "m/s": (1.0, ["mps", "ms-1"]),
            "km/h": (1 / 3.6, ["kmh", "kph", "kmph"]),
            "mph": (0.44704, ["mi/h"]),
            "ft/s": (0.3048, ["fps"]),
            "kn": (0.514444444444, ["knot", "knots", "kt"]),
            "mach": (340.29, []),
        },
    },
    "time": {
        "base": "s",
        "companions": ["s", "min", "h", "d"],
        "units": {
            "ns": (1e-9, ["nanosecond", "nanoseconds"]),
            "us": (1e-6, ["µs", "microsecond", "microseconds"]),
            "ms": (1e-3, ["millisecond", "milliseconds"]),
            "s": (1.0, ["sec", "secs", "second", "seconds"]),
            "min": (60.0, ["minute", "minutes"]),
            "h": (3600.0, ["hr", "hrs", "hour", "hours"]),
            "d": (86400.0, ["day", "days"]),
            "wk": (604800.0, ["week", "weeks"]),
            "mo": (2629800.0, ["month", "months"]),
            "yr": (31557600.0, ["year", "years", "y"]),
        },
    },
    "data": {
        "base": "b",
        "companions": ["mb", "gb", "mib", "gib"],
        "units": {
            # Byte is the base. `bit` is 1/8 of it; the decimal (SI) and binary
            # (IEC) ladders both live here so `conv 1 gb mib` just works.
            "bit": (0.125, ["bits"]),
            "b": (1.0, ["byte", "bytes"]),
            "kb": (1e3, ["kilobyte", "kilobytes"]),
            "mb": (1e6, ["megabyte", "megabytes"]),
            "gb": (1e9, ["gigabyte", "gigabytes"]),
            "tb": (1e12, ["terabyte", "terabytes"]),
            "pb": (1e15, ["petabyte", "petabytes"]),
            "kib": (1024.0, ["kibibyte"]),
            "mib": (1024.0 ** 2, ["mebibyte"]),
            "gib": (1024.0 ** 3, ["gibibyte"]),
            "tib": (1024.0 ** 4, ["tebibyte"]),
            "pib": (1024.0 ** 5, ["pebibyte"]),
        },
    },
    "pressure": {
        "base": "pa",
        "companions": ["bar", "psi", "atm", "kpa"],
        "units": {
            "pa": (1.0, ["pascal", "pascals"]),
            "hpa": (100.0, ["hectopascal"]),
            "kpa": (1e3, ["kilopascal"]),
            "mpa": (1e6, ["megapascal"]),
            "bar": (1e5, ["bars"]),
            "mbar": (100.0, ["millibar"]),
            "atm": (101325.0, ["atmosphere", "atmospheres"]),
            "psi": (6894.757293168, ["lbf/in2"]),
            "torr": (133.32236842105263, []),
            "mmhg": (133.322387415, []),
        },
    },
    "energy": {
        "base": "j",
        "companions": ["j", "kj", "kcal", "kwh"],
        "units": {
            "j": (1.0, ["joule", "joules"]),
            "kj": (1e3, ["kilojoule", "kilojoules"]),
            "mj": (1e6, ["megajoule"]),
            "cal": (4.184, ["calorie", "calories"]),
            "kcal": (4184.0, ["kilocalorie", "kilocalories"]),
            "wh": (3600.0, ["watthour"]),
            "kwh": (3.6e6, ["kilowatthour"]),
            "btu": (1055.05585262, []),
            "ev": (1.602176634e-19, ["electronvolt"]),
        },
    },
    "power": {
        "base": "w",
        "companions": ["w", "kw", "hp"],
        "units": {
            "mw-milli": (1e-3, ["milliwatt"]),
            "w": (1.0, ["watt", "watts"]),
            "kw": (1e3, ["kilowatt", "kilowatts"]),
            "mw": (1e6, ["megawatt", "megawatts"]),
            "gw": (1e9, ["gigawatt"]),
            "hp": (745.6998715822702, ["horsepower"]),
        },
    },
    "angle": {
        "base": "deg",
        "companions": ["deg", "rad", "grad"],
        "units": {
            "deg": (1.0, ["degree", "degrees", "°"]),
            "rad": (57.29577951308232, ["radian", "radians"]),
            "grad": (0.9, ["gradian", "gon"]),
            "turn": (360.0, ["turns", "rev"]),
            "arcmin": (1 / 60.0, []),
            "arcsec": (1 / 3600.0, []),
        },
    },
    "frequency": {
        "base": "hz",
        "companions": ["hz", "khz", "mhz", "ghz"],
        "units": {
            "hz": (1.0, ["hertz"]),
            "khz": (1e3, ["kilohertz"]),
            "mhz": (1e6, ["megahertz"]),
            "ghz": (1e9, ["gigahertz"]),
            "thz": (1e12, ["terahertz"]),
            "rpm": (1 / 60.0, ["revolutionsperminute"]),
        },
    },
}

# --- temperature --------------------------------------------------------------
#
# Affine, not linear: 0 °C is not 0 °F, so a single multiplier cannot express it.
# Base is kelvin; each unit supplies to_base / from_base.

TEMPERATURE = {
    "base": "c",
    "companions": ["c", "f", "k"],
    "units": {
        "c": (lambda v: v + 273.15, lambda k: k - 273.15, ["celsius", "centigrade", "°c"]),
        "f": (lambda v: (v + 459.67) * 5 / 9, lambda k: k * 9 / 5 - 459.67, ["fahrenheit", "°f"]),
        "k": (lambda v: v, lambda k: k, ["kelvin"]),
        "r": (lambda v: v * 5 / 9, lambda k: k * 9 / 5, ["rankine"]),
    },
}


def _build_index():
    """Flatten every dimension into one alias -> (dimension, canonical) map.

    Built once at import. Later dimensions do not clobber earlier ones: the first
    registration of an alias wins, so the DIMENSIONS order above is the tie-break
    for the handful of symbols that appear twice (`mw` megawatt vs milliwatt is
    disambiguated by spelling instead — see `mw-milli`).
    """
    idx = {}

    def put(alias, dim, canonical):
        key = alias.strip().lower()
        if key and key not in idx:
            idx[key] = (dim, canonical)

    for dim, spec in DIMENSIONS.items():
        for canonical, (_factor, aliases) in spec["units"].items():
            put(canonical, dim, canonical)
            for a in aliases:
                put(a, dim, canonical)

    for canonical, (_to, _from, aliases) in TEMPERATURE["units"].items():
        put(canonical, "temperature", canonical)
        for a in aliases:
            put(a, "temperature", canonical)

    return idx


INDEX = _build_index()


def lookup(token):
    """Resolve a token to (dimension, canonical unit), or None."""
    return INDEX.get(token.strip().lower())


def convert(value, dim, src, dst):
    """Convert `value` from `src` to `dst`, both canonical units of `dim`."""
    if dim == "temperature":
        to_base = TEMPERATURE["units"][src][0]
        from_base = TEMPERATURE["units"][dst][1]
        return from_base(to_base(value))
    units = DIMENSIONS[dim]["units"]
    return value * units[src][0] / units[dst][0]


def companions(dim, exclude):
    """Default targets for a bare `conv 10 km` — the dimension's usual suspects."""
    spec = TEMPERATURE if dim == "temperature" else DIMENSIONS[dim]
    return [u for u in spec["companions"] if u != exclude]


def display(dim, unit):
    """Human-facing spelling of a canonical unit."""
    if dim == "temperature":
        return {"c": "°C", "f": "°F", "k": "K", "r": "°R"}.get(unit, unit)
    if dim == "data":
        # The byte ladder reads wrong lowercased: "1.5 gb" should render "GB",
        # and the IEC units keep their lowercase `i` — "GiB", not "GIB".
        if unit == "bit":
            return "bit"
        if unit.endswith("ib"):
            return unit[:-2].upper() + "iB"
        return unit.upper()
    if dim == "area" and unit.endswith("2"):
        return unit[:-1] + "²"
    if unit == "mw-milli":
        return "mW"
    return unit
