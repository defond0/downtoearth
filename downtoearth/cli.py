#!/usr/bin/env python
"""downtoearth creates terraform files from api configuration definitions."""
import argparse
import os

from downtoearth.model import ApiModel


def parse_args():
    """Parse arguments."""
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(help='command')

    generate_parser = subparsers.add_parser('generate', help='generate a terraform API file')
    generate_parser.add_argument(
        '-c',
        '--composable',
        action='store_true',
        help='Modify output to permit combining with other terraform configurations'
    )
    generate_parser.add_argument(
        '-q',
        '--quite',
        action='store_true',
        help="Don't echo the terraform"
    )
    generate_parser.add_argument('input', help="dte.json configuration file")
    generate_parser.add_argument('output', help="destination for .tf file")
    generate_parser.set_defaults(execute_step=generate)

    deploy_parser = subparsers.add_parser('deploy', help='deploy lambda code to a stage')
    deploy_parser.add_argument('terraform', nargs='?', default=os.getcwd(), help="where the .tf lives (for reading outputs)")
    deploy_parser.set_defaults(execute_step=deploy)



    args = parser.parse_args()
    return args

def generate(args):
    model = ApiModel(args)
    output = model.render_terraform()
    with open(args.output, "w") as f:
        f.write(output)
    if not args.quite:
        print(output)

def deploy(args):
    raise NotImplementedError("TODO: run terraform output %s (or maybe even read the state file directly)"%args.terraform)




def main():
    """Build template and output to file."""
    args=parse_args()

    if args.execute_step:
        args.execute_step(args)



if __name__ == "__main__":
    main()
