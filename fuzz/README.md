This folder contains scripts related to fuzzing, either ClevFuzz or WAFLGo baseline experiment.

- `clevfuzz.sh`: Script to run ClevFuzz for target program, given a finished Cleverest experiment.
- `checkfuzz.sh`: Script to check the results of ClevFuzz for target program under all experiments found.
- `checkseeds.sh`: Scripts to check closeness of initial seeds used for baseline fuzzing (WAFGo).
- `waflgo`: Folder containing scripts to run WAFLGo baseline experiment, see README.md inside for more details.