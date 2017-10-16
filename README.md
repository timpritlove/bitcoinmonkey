# BitcoinMonkey

Script that reads Bitcoin Core CSV export files, retrieves historical Bitcoin prices via CoinBase and converts it to CSV format ready to be imported to MonkeyOffice. Written in Lua.

## Requirements

Install the following lua dependencies using luarocks

* `luarocks install csv`
* `luarocks install date`
* `luarocks install lua_cliargs`
* `luarocks install lua-requests`

## Usage

```
Usage: lua BitcoinMonkey.lua [OPTIONS] [--] CSVDATEI

ARGUMENTS: 
  CSVDATEI                    Bitcoin Core CSV Exportdatei (required)

OPTIONS: 
  -w, --waehrung=WAEHRUNG     Währung (default: EUR)
  -f, --finanzkonto==KONTO    Finanzkonto
  -g, --gegenkonto==KONTO     Gegenkonto
  -s, --steuersatz=STEUERSATZ Steuersatz (default: -)
  -1, --ks1=KOSTENSTELLE      Kostenstelle1
  -2, --ks2=KOSTENSTELLE      Kostenstelle2
  -n, --firma=NR              Firmennummer (default: 0)
  -b, --bestand=BTC           Initialer Bestand des BTC-Kontos (default: 0)
```