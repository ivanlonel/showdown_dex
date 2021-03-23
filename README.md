# showdown_dex

## Example usage

Clone repository and initialize submodule
```bash
git clone https://github.com/ivanlonel/showdown_dex.git
cd showdown_dex
git submodule update --init --recursive
```

You may need to install python3-venv for the next step. For example, in Debian:
```bash
sudo apt update && sudo apt install python3-venv
```

Create virtual environment, activate it and upgrade its pip
```bash
python3 -m venv env  # --upgrade-deps  # This option is Python 3.9+ only
source env/bin/activate
python -m pip install --upgrade pip  # If venv was not created with --upgrade-deps
```

Install python dependencies in virtual environment
```bash
pip install -r requirements.txt
```

Download smogon analyses as json files
```bash
python smogon_analyses.py
```

Fire up the database. Unless you're using Docker Desktop with WSL, you must have docker and docker-compose installed.
```bash
sudo docker-compose up --detach
```

ETL data from .json and .ts files into the database
```bash
python showdown_dex.py
```

Done. Database is running and ready to be queried.

The repository and the submodule can be updated like this:
```bash
git pull --recurse
git submodule update --remote --rebase
```

Sets and strategies are © 2004-2021 Smogon.com and its [contributors](https://www.smogon.com/credits).
Pokémon and all respective names are Trademark & © of Nintendo 1995-2021.
