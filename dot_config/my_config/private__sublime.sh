#!/bin/bash -e
#      ^----- get shellcheck hints based on bash
# https://github.com/koalaman/shellcheck/issues/809#issuecomment-631194320

# FIXME: Create new project file per project with path to the .venv Python
# Then open with subl using the "--project" arg
# // https://www.sublimetext.com/docs/projects.html
# // https://www.sublimelinter.com/en/stable/settings.html#project-settings
# // Check "show_hover_line_report" and "show_hover_region_report"
# {
#     "folders": [{"path": "/Users/kyleking/Developer/recipes"}],,
#     "settings": {
#         "SublimeLinter.linters.flake8.args": [
#             "--max-line-length=88",
#             "--ignore=B902,D100,D103,D205,D209,D400,D401,D403,E203,E501,E722,W503",
#             "--select=A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z"
#         ],
#         "SublimeLinter.linters.flake8.python": "$project_path/.env/bin/python",
#         "SublimeLinter.linters.pylint.args": [
#             "--disable=E0012,E0401,W0613,C0115,C0116,W1203",
#             "--rcfile=./reviewer-api/.pylintrc"
#         ],
#         "SublimeLinter.linters.pylint.python": "$project_path/.env/bin/python"
#     }
# }
