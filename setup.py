"""
Setup script for AwiOS - Visual Novel Engine
"""

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="awios-engine",
    version="1.0.0",
    author="Awi-24",
    description="AwiOS - Visual Novel Engine. Python + Flet smartphone-style UI for interactive stories.",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/Awi-24/AWI-engine",
    packages=find_packages(),
    py_modules=["main"],
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
    ],
    python_requires=">=3.10",
    install_requires=[
        "flet>=0.21.0",
        "pydantic>=2.0.0",
    ],
    extras_require={
        "dev": [
            "pyinstaller>=6.0.0",
        ],
    },
    entry_points={
        "console_scripts": [
            "awios=main:main",
        ],
    },
)
