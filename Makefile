.PHONY: clean clean-build clean-pyc clean-test coverage deploy-docs dist docs docs help install lint release test
.DEFAULT_GOAL := help

# project variables
PROJECT_NAME := downtoearth
PROJECT_NAME_NODASH := downtoearth
VERSION := $(shell git describe --always --dirty)

define BROWSER_PYSCRIPT
import os, webbrowser, sys
try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT
BROWSER := python -c "$$BROWSER_PYSCRIPT"

help:
	$(info available targets:)
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		nb = sub( /^## /, "", helpMsg ); \
		if(nb == 0) { \
			helpMsg = $$0; \
			nb = sub( /^[^:]*:.* ## /, "", helpMsg ); \
		} \
		if (nb) \
			print  $$1 "\t" helpMsg; \
	} \
	{ helpMsg = $$0 }' \
	$(MAKEFILE_LIST) | column -ts $$'\t' | \
	grep --color '^[^ ]*'

clean: clean-build clean-pyc clean-test ## remove all build, test, coverage and Python artifacts

clean-build: ## remove build artifacts
	rm -fr build/
	rm -fr dist/
	rm -fr .eggs/
	find . -name '*.egg-info' -exec rm -fr {} +
	find . -name '*.egg' -exec rm -f {} +

clean-pyc: ## remove Python file artifacts
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	find . -name '__pycache__' -exec rm -fr {} +

clean-test: ## remove test and coverage artifacts
	rm -fr .tox/
	rm -f .coverage
	rm -fr htmlcov/

coverage: ## check code coverage quickly with the default Python
	coverage run --source downtoearth setup.py test
	coverage report -m
	coverage html
	$(BROWSER) htmlcov/index.html

deploy-docs: docs # deploy docs to S3 bucket (not needed; docs on RTD)
	aws s3 sync ./docs/_build/html/ s3://cleardata-internal-documentation/downtoearth/

dist: clean ## builds source and wheel package
	python setup.py sdist
	python setup.py bdist_wheel
	ls -l dist

docs: ## generate Sphinx HTML documentation, including API docs
	rm -f docs/downtoearth.rst
	rm -f docs/modules.rst
	sphinx-apidoc -o docs/ downtoearth
	$(MAKE) -C docs clean
	$(MAKE) -C docs html
	$(BROWSER) docs/_build/html/index.html

install: clean ## install the package to the active Python's site-packages
	python setup.py install

lint: ## check style with flake8
	PYFLAKES_NODOCTEST=1 flake8 downtoearth tests

publish: req-publish-registry
	python setup.py sdist upload -r $(PUBLISH_REGISTRY)
	python setup.py bdist_wheel upload -r $(PUBLISH_REGISTRY)

release: req-release-type req-release-repo clean ## package and upload a release
	release -t $(RELEASE_TYPE) -g $(RELEASE_REPO) $(RELEASE_BRANCH) $(RELEASE_BASE)

req-publish-registry:
	ifndef PUBLISH_REGISTRY
		$(error PUBLISH_REGISTRY is undefined)
	endif

req-release-type:
	ifndef RELEASE_TYPE
		$(error RELEASE_TYPE is undefined)
	endif

req-release-repo:
	ifndef RELEASE_REPO
		$(error RELEASE_REPO is undefined)
	endif

test: ## run tests quickly with the default Python
	python setup.py test
