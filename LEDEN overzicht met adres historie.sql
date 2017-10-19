﻿---------------------------------------------------------------------------------------------------------
-- OVERZICHT QUERIES:
-- - UC
-- - adres historie met de afdeling volgens de regionale definitie per res_partner.id
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
--------------------------------------------------------------
--bevat:
-- - bepalen variabelen
-- - ophalen data
-- - berekening statistieken
-- - berekening fiscale attesten
-- - andere losse hulp queries
--------------------------------------
--Opmerking: aparte query voor domicilieringen (foutieve linking naar facturen) werd niet meer overgenomen uit v2
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
INSERT INTO tempLEDEN_verhuizers
	(SELECT p.id, p.zip, p.city, NULL, NULL, COALESCE(COALESCE(a2.name,a.name),'onbekend'), NULL
	FROM res_partner p
		JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
	--WHERE p.id = 169997
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








SELECT pah.id, 
	LAG(pah.zip,1,pah.zip) OVER (PARTITION BY pah.partner_id ORDER BY pah.id) vorige_postcode,
	LAG(pah.city,1,pah.city) OVER (PARTITION BY pah.partner_id ORDER BY pah.id) vorige_gemeente 
FROM res_partner_address_history pah 
WHERE partner_id = 169997 ORDER BY pah.id DESC LIMIT 1


LAG(pah.zip,1,pah.zip) OVER (PARTITION BY p.partner_id ORDER BY pah.id)
---------------------------------------------------------------------------------------------------------
SELECT p.id, COALESCE(a2.id,a.id) id, COALESCE(a2.name,a.name) afdeling
FROM res_partner p
	--afdeling vs afdeling eigen keuze
	LEFT OUTER JOIN res_partner a ON p.department_id = a.id
	LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
	------------
	JOIN
	(SELECT * FROM (
	SELECT pah.partner_id, pah.city, pah.zip, reg_def.afdeling_id, reg_def.afdeling, ROW_NUMBER() OVER (PARTITION BY pah.partner_id ORDER BY pah.id DESC) AS r,
		CASE
			WHEN ROW_NUMBER() OVER (PARTITION BY pah.partner_id ORDER BY pah.id DESC) = 1 THEN 'huidige afdeling'
			WHEN ROW_NUMBER() OVER (PARTITION BY pah.partner_id ORDER BY pah.id DESC) > 1 THEN 'vorige afdeling'
		END afd_hist
	FROM res_partner_address_history pah --tabel met adreshistorie
	--subquery de regional definitie van de afdelingen op
		JOIN (SELECT cc.zip, cc.name gemeente, ocr.partner_id, a1.id afdeling_id, a1.name afdeling
			FROM res_country_city cc 
				JOIN res_organisation_city_rel ocr ON cc.id = ocr.zip_id
				JOIN res_partner a1 ON ocr.partner_id = a1.id
		) reg_def ON pah.zip = reg_def.zip --op basis van zip worden adreshistorie en regionale definitie aan elkaar gekoppeld om de afdeling toe te voegen aan de adres historie	
	) x WHERE x.r = 1
	) afd_hist_1 ON p.id = afd_hist_1.partner_id
	------------		
WHERE p.id = 169997
/*
SELECT pah.partner_id, pah.city, pah.zip, reg_def.afdeling_id, reg_def.afdeling, ROW_NUMBER() OVER (PARTITION BY pah.partner_id ORDER BY pah.id DESC) AS r,
	CASE
		WHEN ROW_NUMBER() OVER (PARTITION BY pah.partner_id ORDER BY pah.id DESC) = 1 THEN 'huidige afdeling'
		WHEN ROW_NUMBER() OVER (PARTITION BY pah.partner_id ORDER BY pah.id DESC) > 1 THEN 'vorige afdeling'
	END afd_hist
FROM res_partner_address_history pah --tabel met adreshistorie
--subquery de regional definitie van de afdelingen op
	JOIN (SELECT cc.zip, cc.name gemeente, ocr.partner_id, a1.id afdeling_id, a1.name afdeling
		FROM res_country_city cc 
			JOIN res_organisation_city_rel ocr ON cc.id = ocr.zip_id
			JOIN res_partner a1 ON ocr.partner_id = a1.id
	) reg_def ON pah.zip = reg_def.zip --op basis van zip worden adreshistorie en regionale definitie aan elkaar gekoppeld om de afdeling toe te voegen aan de adres historie
WHERE pah.partner_id = 169997
*/
---------------------------------------------------------------------------------------------------------
-- onderstaande geeft per res_partner.id de adres historie met de afdeling volgens de regionale definitie
---------------------------------------------------------------------------------------------------------
SELECT pah.id, pah.date_move, pah.city, pah.zip, reg_def.afdeling_id, reg_def.afdeling, ROW_NUMBER() OVER (PARTITION BY pah.partner_id ORDER BY pah.id DESC) AS r,
	CASE
		WHEN ROW_NUMBER() OVER (PARTITION BY pah.partner_id ORDER BY pah.id DESC) = 1 THEN 'huidige afdeling'
		WHEN ROW_NUMBER() OVER (PARTITION BY pah.partner_id ORDER BY pah.id DESC) > 1 THEN 'vorige afdeling'
	END afd_hist
FROM res_partner_address_history pah --tabel met adreshistorie
--subquery de regional definitie van de afdelingen op
	JOIN (SELECT cc.zip, cc.name gemeente, ocr.partner_id, a1.id afdeling_id, a1.name afdeling
		FROM res_country_city cc 
			JOIN res_organisation_city_rel ocr ON cc.id = ocr.zip_id
			JOIN res_partner a1 ON ocr.partner_id = a1.id
	) reg_def ON pah.zip = reg_def.zip --op basis van zip worden adreshistorie en regionale definitie aan elkaar gekoppeld om de afdeling toe te voegen aan de adres historie
WHERE pah.partner_id = 169997--118852--291098--
---------------------------------------------------------------------------------------------------------
-- onderstaande geeft per res_partner.id de adres historie met de afdeling volgens de regionale definitie
-- - en gegroepeerd volgens afdeling, woonplaats (pc, gemeente) met max(date_move) per groepering
-- - LIMIT 2 geeft TOP 2 om enkel de 'recente' verhuizers op te lijsten
---------------------------------------------------------------------------------------------------------
SELECT max(date_move) "date", afdeling_id, afdeling, city, zip, afd_hist verhuis_beweging
FROM
(
	SELECT pah.id, pah.date_move, pah.city, pah.zip, reg_def.afdeling_id, reg_def.afdeling, ROW_NUMBER() OVER (PARTITION BY pah.partner_id ORDER BY pah.id DESC) AS r,
		CASE
			WHEN ROW_NUMBER() OVER (PARTITION BY pah.partner_id ORDER BY pah.id DESC) = 1 THEN 'huidige afdeling'
			WHEN ROW_NUMBER() OVER (PARTITION BY pah.partner_id ORDER BY pah.id DESC) > 1 THEN 'vorige afdeling'
		END afd_hist
	FROM res_partner_address_history pah --tabel met adreshistorie
	--subquery de regional definitie van de afdelingen op
		JOIN (SELECT cc.zip, cc.name gemeente, ocr.partner_id, a1.id afdeling_id, a1.name afdeling
			FROM res_country_city cc 
				JOIN res_organisation_city_rel ocr ON cc.id = ocr.zip_id
				JOIN res_partner a1 ON ocr.partner_id = a1.id
		) reg_def ON pah.zip = reg_def.zip --op basis van zip worden adreshistorie en regionale definitie aan elkaar gekoppeld om de afdeling toe te voegen aan de adres historie
	WHERE pah.partner_id = 169997--118852--291098--
) x
GROUP BY afdeling_id, afdeling, zip, city, afd_hist
ORDER BY max(date_move) DESC
LIMIT 2
---------------------------------------------------------------------------------------------------------
-- bovenstaande QRY in functie gezet om vlotter mee te kunnen werken als subquery of fie veld
---------------------------------------------------------------------------------------------------------
SELECT * FROM _crm_ledenverhuisinfotop2(226931);  -- !!!!! WERKT NIET ZOALS VERWACHT !!!!!
---------------------------------------------------------------------------------------------------------
-- poging tot gebruik van fie in QRY: lukt wel met 'huidige afdeling' niet met 'vorige afdeling' (in WHERE clause)
---------------------------------------------------------------------------------------------------------
SELECT (SELECT DISTINCT afdeling FROM _crm_ledenverhuisinfotop2(p.id) WHERE verhuisbeweging = 'huidige afdeling') "in",
	(SELECT DISTINCT afdeling FROM _crm_ledenverhuisinfotop2(p.id) WHERE verhuisbeweging = 'vorige afdeling') uit, --v.*, 
	p.*
FROM res_partner p
	--INNER JOIN (SELECT partner_id, afdeling FROM _crm_ledenverhuisinfotop2(p.id) WHERE verhuisbeweging = 'vorige afdeling') v ON v.partner_id = p.id
WHERE (SELECT DISTINCT afdeling_id FROM _crm_ledenverhuisinfotop2(p.id) WHERE teller = 2) = 248552 
	p.id IN (248599)

SELECT afdeling_id FROM _crm_ledenverhuisinfotop2(18301) WHERE verhuisbeweging = 'vorige afdeling'	

	SELECT * FROM (
	SELECT pah.id, pah.date_move, pah.city, pah.zip, reg_def.afdeling_id, reg_def.afdeling, pah.partner_id, ROW_NUMBER() OVER (PARTITION BY pah.partner_id ORDER BY pah.id DESC) AS r,
		CASE
			WHEN ROW_NUMBER() OVER (PARTITION BY pah.partner_id ORDER BY pah.id DESC) = 1 THEN 'huidige afdeling'
			WHEN ROW_NUMBER() OVER (PARTITION BY pah.partner_id ORDER BY pah.id DESC) > 1 THEN 'vorige afdeling'
		END afd_hist
	FROM res_partner_address_history pah --tabel met adreshistorie
	--subquery de regional definitie van de afdelingen op
		JOIN (SELECT cc.zip, cc.name gemeente, ocr.partner_id, a1.id afdeling_id, a1.name afdeling
			FROM res_country_city cc 
				JOIN res_organisation_city_rel ocr ON cc.id = ocr.zip_id
				JOIN res_partner a1 ON ocr.partner_id = a1.id
		) reg_def ON pah.zip = reg_def.zip --op basis van zip worden adreshistorie en regionale definitie aan elkaar gekoppeld om de afdeling toe te voegen aan de adres historie
	--WHERE pah.partner_id = partner
	) x WHERE x.afdeling_id = 248552 --AND x.r = 1
	ORDER BY x.partner_id



