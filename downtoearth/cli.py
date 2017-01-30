#!/usr/bin/env python
"""downtoearth creates terraform files from api configuration definitions."""
import argparse

from downtoearth.model import ApiModel


def parse_args():
    """Parse arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-c',
        '--composable',
        action='store_true',
        help='Modify output to permit combining with other terraform configurations'
    )
    parser.add_argument(
        '-d',
        '--deploy',
        action='store_true',
        help='Whether to run terraform apply (and post-hooks) on the generated state file'
    )
    parser.add_argument('input')
    parser.add_argument('output')
    return parser.parse_args()


def main():
    """Build template and output to file."""
    args = parse_args()
    print(args)
    model = ApiModel(args)
    output = model.render_terraform()
    with open(args.output, "w") as f:
        f.write(output)
    print(output)
    if args.deploy:
        model.run_terraform()


if __name__ == "__main__":
    main()
