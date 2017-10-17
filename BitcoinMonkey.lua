-- BitcoinMonkey.lua
--
-- Umwandlung einer Bitcoin Core CSV Exportdatei in MonkeyOffice Buchungen

--- TODO:
--- - Angabe der Ausgabedatei

local ftcsv = require("ftcsv")
local date = require("date")
local cli = require ("cliargs")
local requests = require ("requests")


--
-- Hilfsfunktionen zur String-Behandlung
--

local DELIM = "," -- Delimiter

local function csvField (str)
  -- Helper function for quoting delimiter character and escaping double quotes.
  if str == nil or str == "" then
    return ""
  end
  return '"' .. string.gsub(str, '"', '""') .. '"'
end


-- Command Line Usage

cli:set_name("BitcoinMonkey")
cli:set_description("Umwandlung einer Bitcoin Core CSV Exportdatei in MonkeyOffice Buchungen")
cli:argument("CSVDATEI", "Bitcoin Core CSV Exportdatei")
cli:option("-w, --waehrung=WAEHRUNG", "Währung", "EUR")
cli:option("-f, --finanzkonto=KONTO", "Finanzkonto")
cli:option("-g, --gegenkonto=KONTO", "Gegenkonto")
cli:option("-s, --steuersatz=STEUERSATZ", "Steuersatz", "-")
cli:option("-1, --ks1=KOSTENSTELLE", "Kostenstelle1", "")
cli:option("-2, --ks2=KOSTENSTELLE", "Kostenstelle2", "")
cli:option("-n, --firma=NR", "Firmennummer", "0")
cli:option("-b, --bestand=BTC", "Initialer Bestand des BTC-Kontos", "0")
cli:option("-d, --startdatum=DATE", "Frühestes Datum")
cli:option("-D, --endedatum=DATE", "Spätestes Datum")
cli:option("-o, --output=OFILE", "Ausgabedatei")


-- Kommandozeile parsen und auf Vollständigkeit überprüfen

local args, err = cli:parse(arg)

if not args and err then
  print(string.format('%s: %s', cli.name, err))
  cli:print_help()
  os.exit(1)
end

if not args.finanzkonto or not args.gegenkonto then
  print "Die Angabe von Finanzkonto und Gegenkonto ist erforderlich"
  print(string.format('%s: %s', cli.name, err))
  os.exit(1)
end


local BestandBTC = tonumber(args.bestand)
local Finanzkonto = tostring(args.finanzkonto)
local Gegenkonto = tostring(args.gegenkonto)
local Waehrung = tostring(args.waehrung)
local Steuersatz = tostring(args.waehrung)
local Kostenstelle1 = tostring(args.ks1)
local Kostenstelle2 = tostring(args.ks2)
local Firma = tostring(args.firma)
local StartDatum = nil
local EndeDatum = nil


if args.startdatum then
  StartDatum = date(tostring(args.startdatum))
end

if args.endedatum then
  EndeDatum = date(tostring(args.endedatum))
end


-- CSV Datei öffnen und konvertieren

local Transaktionen = ftcsv.parse(args["CSVDATEI"], DELIM, { header = true })

if Transaktionen == nil then
  print (string.format ("Die Datei '%s' kann nicht geöffnet werden", args["CSVDATEI"]))
  os.exit (1)
end

print ( "Firma" .. DELIM .. "Datum" .. DELIM .. 
        "BelegNr"  .. DELIM .. "Referenz"  .. DELIM ..
        "Waehrung" .. DELIM .. "Text" .. DELIM ..
        "KontoSoll" .. DELIM .. "KontoHaben" .. DELIM ..
        "Betrag" .. DELIM .."Steuersatz" .. DELIM ..
        "Kostenstelle1" .. DELIM .."Kostenstelle2" .. DELIM .. "Notiz" )

-- Transaktionen nach Datum sortieren

table.sort(Transaktionen, function (a,b)
	 return date(a.Date) < date(b.Date)
end)


for n, Transaktion in ipairs(Transaktionen) do

  TransaktionsDatum = date(Transaktion.Date)

  if (not StartDatum or StartDatum <= TransaktionsDatum) and
     (not EndeDatum or EndeDatum >= TransaktionsDatum) and
     (Transaktion.Confirmed == "true") then

    Datum = string.format ("%02d.%02d.%04d", TransaktionsDatum:getday(), TransaktionsDatum:getmonth(), TransaktionsDatum:getyear())

    BetragBTC = tonumber(Transaktion["Amount (BTC)"])
    BestandBTC = BestandBTC + BetragBTC

    -- Historischen Umrechnungskurs erfragen
    
    RequestDate = string.format ("%04s-%02s-%02s", TransaktionsDatum:getyear(), TransaktionsDatum:getmonth(), TransaktionsDatum:getday())
    RequestURL = string.format ("https://api.coindesk.com/v1/bpi/historical/close.json?currency=%s&start=%s&end=%s",
                                Waehrung, RequestDate, RequestDate )
    Response = requests.get(RequestURL)
    if (Response.status_code ~= 200) then
      print(string.format("Request to '%s' results in Status %s", RequestURL, Response.status_code) )
      os.exit (1)
    end
    Result, Error = Response.json()
    Wechselkurs = Result.bpi[RequestDate]
    BetragWaehrung = string.gsub(string.format ("%.2f", Wechselkurs * BetragBTC), "%.", "," )

    if Transaktion.Type == "Received with" then
      Text = string.format("Erwerb: %.8f / Neuer Bestand: %.8f", BetragBTC, BestandBTC)
    else
      Text = string.format("Verkauf: %.8f / Neuer Bestand: %.8f", math.abs(BetragBTC), BestandBTC)
    end

    Notiz = string.format("CoinBase BPI: %f ( x %f = %f %s / Label: %s", Wechselkurs, BetragBTC,  Wechselkurs * BetragBTC, Waehrung, Transaktion.Label)

    print(string.format('%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s',
      csvField(Firma), DELIM,                 -- Firma
      csvField(Datum), DELIM,                 -- Datum
      csvField(Transaktion.ID), DELIM,        -- BelegNr
      csvField(Transaktion.Address), DELIM,   -- Referenz
      csvField(Waehrung), DELIM,              -- Währung
      csvField(Text), DELIM,                  -- Text
      csvField(Finanzkonto), DELIM,           -- KontoSoll
      csvField(Gegenkonto), DELIM,            -- KontoHaben
      csvField(BetragWaehrung), DELIM,        -- Betrag
      csvField(Steuersatz), DELIM,            -- Steuersatz
      csvField(Kostenstelle1), DELIM,         -- Kostenstelle1
      csvField(Kostenstelle2), DELIM,         -- Kostenstelle2
      csvField(Notiz)                         -- Notiz
    ))


  end

end

