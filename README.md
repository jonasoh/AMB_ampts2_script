# AMB_ampts2_script

This script processes BMP testing data from AMPTS II systems. It was developed for the [AMB group](https://twitter.com/AMB_SLU) at [SLU](https://www.slu.se/en/departments/molecular-sciences/research-groups/microbial_biotechnology/), but may also be useful for others.

This script relies on the [biogas package](https://cran.r-project.org/web/packages/biogas/index.html) for calculations and was inspired by the [bmp-ampts2 script](https://github.com/alex-bagnoud/bmp-ampts2). 

## Running

The script requires R version 4.1.0 or higher. In order to run the script, convert the AMPTS II log file(s) into Excel (.xlsx) format and place them in a directory together with the setup.xlsx file. Fill in the appropriate information in setup.xlsx, then run the script.

In setup.xlsx, the columns *Substrate mass* and *Inoculum mass* refer to the weighed in masses for each bottle, whereas the *Substrate VS* and *VS STDEV* columns refer to the characteristics of the substrate. The inoculum control is defined as the group without any substrate mass (0 or undefined). There must be exactly one inoculum control group in the data in order for the script to work.

## Limitations

This script is in an early state of development and any details are subject to change. Do not rely on it in production yet!
