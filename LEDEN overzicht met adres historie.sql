---------------------------------------------------------------------------------------------------------
-- OVERZICHT QUERIES:
-- - UC
-- - adres historie met de afdeling volgens de regionale definitie per res_partner.id
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
--------------------------------------------------------------
-- TODO
-- - afdeling id toevoegen aan temp tabel verhuizers
-- - eind selectie kan dan ook daarop gebeuren
--------------------------------------
-- OPMERKING
-- - aanduiden "vorige" & "volgende" voor 6200 leden duurde 45 min
--------------------------------------------------------------
--SET VARIABLES
/*DROP TABLE IF EXISTS myvar;
SELECT 
	'2016-06-01'::date AS startdatum,
	'2017-12-31'::date AS einddatum,
	'2012-01-01'::date AS startdatumbosvooriedereen,
	'2013-01-01'::date AS startdatumalledonateurs,
	'16980'::numeric AS testID
INTO TEMP TABLE myvar;
SELECT * FROM myvar;*/
---------------------------------------------------------------------------------------------------------
--CREATE TEMP TABLE
DROP TABLE IF EXISTS tempLEDEN_verhuizers;

CREATE TEMP TABLE tempLEDEN_verhuizers (
	partner_id NUMERIC, postcode TEXT, gemeente TEXT, vorige_postcode TEXT, vorige_gemeente TEXT, huidige_afdeling TEXT, vorige_afdeling TEXT);
---------------------------------------------------------------------------------------------------------
-- Eerst potentiële verhuizers ophalen 
---------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS tempLEDEN_potentieel;

CREATE TEMP TABLE tempLEDEN_potentieel (partner_id NUMERIC);

INSERT INTO tempLEDEN_potentieel
	(SELECT pah.partner_id
	FROM res_partner_address_history pah
	WHERE pah.zip IN (SELECT cc.zip
			FROM res_country_city cc 
				JOIN res_organisation_city_rel ocr ON cc.id = ocr.zip_id
			WHERE partner_id = 248566)
	);
---------------------------------------------------------------------------------------------------------
-- Verhuizers tabel vullen met potentiële verhuizers
---------------------------------------------------------------------------------------------------------
INSERT INTO tempLEDEN_verhuizers
	(SELECT p.id, p.zip, p.city, NULL, NULL, COALESCE(COALESCE(a2.name,a.name),'onbekend'), NULL
	FROM tempLEDEN_potentieel pot, res_partner p
		JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
	WHERE p.id = pot.partner_id
	);
---------------------------------------------------------------------------------------------------------
--SELECT * FROM tempLEDEN_verhuizers WHERE partner_id = 169997;
---------------------------------------------------------------------------------------------------------
UPDATE tempLEDEN_verhuizers v
SET vorige_postcode = 
	(SELECT LAG(pah.zip,1,pah.zip) OVER (PARTITION BY pah.partner_id ORDER BY pah.id) vorige_postcode
	FROM res_partner_address_history pah 
	WHERE pah.partner_id = v.partner_id ORDER BY pah.id DESC LIMIT 1);
	
UPDATE tempLEDEN_verhuizers v
SET vorige_gemeente = 
	(SELECT LAG(pah.city,1,pah.city) OVER (PARTITION BY pah.partner_id ORDER BY pah.id)
	FROM res_partner_address_history pah 
	WHERE pah.partner_id = v.partner_id ORDER BY pah.id DESC LIMIT 1);

UPDATE tempLEDEN_verhuizers v
SET vorige_afdeling =
	(SELECT a1.name afdeling
	FROM res_country_city cc 
		JOIN res_organisation_city_rel ocr ON cc.id = ocr.zip_id
		JOIN res_partner a1 ON ocr.partner_id = a1.id
	WHERE cc.zip = v.vorige_postcode);


SELECT * FROM tempLEDEN_verhuizers WHERE huidige_afdeling = 'Natuurpunt Hasselt-Zonhoven' OR vorige_afdeling = 'Natuurpunt Hasselt-Zonhoven'







