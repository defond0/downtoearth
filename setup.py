#!/usr/bin/env python

from setuptools import setup

setup(name='downtoearth',
      version='0.3.1',
      description='Utility to make API Gateway terraforms',
      author='ClearDATA',
      url='http://gitlab.eng.cleardata.com/serverless/downtoearth',
      packages=['downtoearth'],
      scripts=['bin/downtoearth-cli.py'],
      package_data={'downtoearth': [
          'templates/*.hcl',
      ]},
      setup_requires=['pytest-runner',],
      tests_require=[
          'pytest',
      ],
      entry_points={
          'console_scripts': [
              'downtoearth = downtoearth.cli:main',
          ]
      },
     )
