-- BitcoinMonkey.lua
--
-- Umwandlung einer Bitcoin Core CSV Exportdatei in MonkeyOffice Buchungen

--- TODO:
--- - BTC Betrag nach historischem Wechselkurs in Waehrung umwandeln
--- - Fließkommazahlen mit Komma als Dezimaltrenner?
--- - Alle Einträge zu Beginn nach Datum und Zeit sortieren

local csv = require("csv")
local date = require("date")
local cli = require ("cliargs")
local requests = require ("requests")


--
-- Hilfsfunktionen zur String-Behandlung
--

local DEL = "," -- Delimiter

local function csvField (str)
  -- Helper function for quoting delimiter character and escaping double quotes.
  if str == nil or str == "" then
    return ""
  end
  return '"' .. string.gsub(str, '"', '""') .. '"'
end


-- Command Line Usage

-- lua BitconMonkey.lua <OPTIONS> CSVDATEI
--
--    CSVDATEI                Bitcoin Core CSV Exportdatei
--    --bestand BESTAND       Initialer Bestand des BTC-Kontos (default: 0)
--    --finanzkonto FKONTO    Finanzkonto
--    --gegenkonto GKONTO     Gegenkonto
--    --kurse KDATEI          Lookup-Datei für Bitcoin-Kurse
--    --waehrung WAEHRUNG     Währung (default: EUR)
--    --steuersatz STEUER     Steuersatz (default: "-")
--    --ks1 KS1               Kostenstelle1 (default: "")
--    --ks2 KS2               Kostenstelle2 (default: "")



cli:set_name("BitcoinMonkey")
cli:set_description("Umwandlung einer Bitcoin Core CSV Exportdatei in MonkeyOffice Buchungen")
cli:argument("CSVDATEI", "Bitcoin Core CSV Exportdatei")
cli:option("-w, --waehrung=WAEHRUNG", "Währung", "EUR")
cli:option("-f, --finanzkonto==KONTO", "Finanzkonto")
cli:option("-g, --gegenkonto==KONTO", "Gegenkonto")
cli:option("-s, --steuersatz=STEUERSATZ", "Steuersatz", "-")
cli:option("-1, --ks1=KOSTENSTELLE", "Kostenstelle1", "")
cli:option("-2, --ks2=KOSTENSTELLE", "Kostenstelle2", "")
cli:option("-n, --firma=NR", "Firmennummer", "0")
cli:option("-b, --bestand=BTC", "Initialer Bestand des BTC-Kontos", "0")


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



-- CSV Datei öffnen und konvertieren

local file = csv.open(args["CSVDATEI"], { header = true })

if file == nil then
  print (string.format ("Die Datei '%s' kann nicht geöffnet werden", args["CSVDATEI"]))
  os.exit (1)
end

print ( "Firma" .. DEL .. "Datum" .. DEL .. 
        "BelegNr"  .. DEL .. "Referenz"  .. DEL ..
        "Waehrung" .. DEL .. "Text" .. DEL ..
        "KontoSoll" .. DEL .. "KontoHaben" .. DEL ..
        "Betrag" .. DEL .."Steuersatz" .. DEL ..
        "Kostenstelle1" .. DEL .."Kostenstelle2" .. DEL .. "Notiz" )

for Transaktion in file:lines() do

  --  for i, v in pairs(fields) do
  --    print(i, v)
  --    if i == "Date" then
  --      print(assert(date(v)))
  --    end
  --  end

  if Transaktion.Confirmed == "true" then

    Zeitstempel = date(Transaktion.Date)
    Datum = string.format ("%02d.%02d.%04d", Zeitstempel:getday(), Zeitstempel:getmonth(), Zeitstempel:getyear())

    BetragBTC = tonumber(Transaktion["Amount (BTC)"])
    BestandBTC = BestandBTC + BetragBTC

    -- Historischen Umrechnungskurs erfragen
    
    RequestDate = string.format ("%04s-%02s-%02s", Zeitstempel:getyear(), Zeitstempel:getmonth(), Zeitstempel:getday())
    RequestURL = string.format ("https://api.coindesk.com/v1/bpi/historical/close.json?currency=%s&start=%s&end=%s",
                                Waehrung, RequestDate, RequestDate )
    Response = requests.get(RequestURL)
    if (Response.status_code ~= 200) then
      print(string.format("Request to '%s' results in Status %s", RequestURL, Response.status_code) )
      os.exit (1)
    end
    Result, Error = Response.json()
    Wechselkurs = Result.bpi[RequestDate]
    BetragWaehrung = string.format ("%.2f", Wechselkurs * BetragBTC)

    if Transaktion.Type == "Received with" then
      Text = string.format("Erwerb: %.8f / Neuer Bestand: %.8f", BetragBTC, BestandBTC)
    else
      Text = string.format("Verkauf: %.8f / Neuer Bestand: %.8f", math.abs(BetragBTC), BestandBTC)
    end

    Notiz = Transaktion.Label

    print(string.format('%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s',
      csvField(Firma), DEL,                 -- Firma
      csvField(Datum), DEL,                 -- Datum
      csvField(Transaktion.ID), DEL,        -- BelegNr
      csvField(Transaktion.Address), DEL,   -- Referenz
      csvField(Waehrung), DEL,              -- Währung
      csvField(Text), DEL,                  -- Text
      csvField(Finanzkonto), DEL,           -- KontoSoll
      csvField(Gegenkonto), DEL,            -- KontoHaben
      csvField(BetragWaehrung), DEL,        -- Betrag
      csvField(Steuersatz), DEL,            -- Steuersatz
      csvField(Kostenstelle1), DEL,         -- Kostenstelle1
      csvField(Kostenstelle2), DEL,         -- Kostenstelle2
      csvField(Notiz)                       -- Notiz
    ))


  end

end

