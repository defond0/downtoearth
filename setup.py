#!/usr/bin/env python

from setuptools import setup

install_requires = [
    'jinja2>=2.9.5'
]

setup(name='downtoearth',
      version='0.3.0',
      description='Utility to make API Gateway terraforms',
      author='ClearDATA',
      url='https://github.com/cleardataeng/downtoearth',
      packages=['downtoearth'],
      scripts=['bin/downtoearth-cli.py'],
      package_data={'downtoearth': [
          'templates/*.hcl',
      ]},
      install_requires=install_requires,
      setup_requires=['pytest-runner',],
      tests_require=[
          'pytest',
      ],
      entry_points={
          'console_scripts': [
              'downtoearth = downtoearth.downtoearth_cli:main',
          ]
      },
     )
