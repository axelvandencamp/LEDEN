-- INHOUD --------------------------------------------------------------
-- - aanmaak temptabel voor opladen bron gegevens huishoudens
-- - lijst gemeenten per afdeling per land  (aanmaak temptabel + INSERT)
-- VERSION CONTROL -----------------------------------------------------
-- - 09/01/2019: densiteitscijfers per regionale toegevoegd
-- - 04/02/2019: nav fusie gemeenten 01/01/2019 aanpassing:
-- -		- "_AV_temp_aantallenpergemeente" enkel selectie actieve gemeenten
-- -		- "Densiteit per gemeente": sommatie van de aantallen + groeperen op [refnis] (naam van gemeente)
------------------------------------------------------------------------
--SET VARIABLES
DROP TABLE IF EXISTS myvar;
SELECT 
	'2024-01-01'::date AS startdatum, 
	'2025-12-31'::date AS einddatum,
	2023 AS vorigjaar
INTO TEMP TABLE myvar;
SELECT * FROM myvar;
--====================================================================
--====================================================================
----------------------------------------------------------------
-- aanmaak temptabel voor opladen bron gegevens huishoudens
-- - aantal per/gemeente vervangen door aantal/postcode
----------------------------------------------------------------
/*DROP TABLE IF EXISTS _AV_temp_huishoudensvolgenstypepergemeente;

CREATE TABLE _AV_temp_huishoudensvolgenstypepergemeente 
(REFNIS_CODE NUMERIC, REFNIS	TEXT, TOTAAL	 NUMERIC, Totaal_private_huishoudens NUMERIC,	
 veld_e	 NUMERIC, veld_f NUMERIC, veld_g NUMERIC, veld_h NUMERIC, veld_i NUMERIC, veld_j NUMERIC, veld_k NUMERIC, veld_l NUMERIC
);
SELECT * FROM _AV_temp_huishoudensvolgenstypepergemeente ORDER BY refnis_code;
------------
--vaste tabel, niet telkens meer importeren, enkel bij jaarovergang de recente cijfers;
-----
-- tabel NOOIT droppen!!-- --DROP TABLE IF EXISTS marketing._m_so_huishoudensvolgenstypeperpostcode;

CREATE TABLE marketing._m_so_huishoudensvolgenstypeperpostcode 
(jaar NUMERIC, CD_ZIP_ NUMERIC, Totaal_huishoudens NUMERIC);

SELECT * FROM marketing._m_so_huishoudensvolgenstypeperpostcode ORDER BY CD_ZIP_;
*/
----------------------------------------------------------------
-- data moet manueel geïmporteerd worden
--====================================================================
---------------------------------------------------------------------
-- temptabel voor omzetting gemeenten namen BELSTAT naar namen ERP
---------------------------------------------------------------------
/*DROP TABLE IF EXISTS _AV_temp_omzettingstabelgemeenten;

CREATE TABLE _AV_temp_omzettingstabelgemeenten 
(REFNIS_CODE NUMERIC, REFNIS TEXT, ERP_gemeente TEXT, dummy TEXT, omzetting TEXT
);
SELECT * FROM _AV_temp_omzettingstabelgemeenten;*/
----------------------------------------------------------------
-- data moet manueel geïmporteerd worden
---------------------------------------------------------------------------------------------------------------------
-- UPDATE "_AV_temp_huishoudensvolgenstypepergemeente" met ERP gemeente namen ahv "_AV_temp_omzettingstabelgemeenten"
---------------------------------------------------------------------------------------------------------------------
/*UPDATE _AV_temp_huishoudensvolgenstypepergemeente h
SET refnis = (SELECT o.omzetting FROM _AV_temp_omzettingstabelgemeenten o WHERE o.refnis_code = h.refnis_code ) WHERE refnis_code IN (SELECT refnis_code FROM _AV_temp_omzettingstabelgemeenten)*/
--====================================================================
---------------------------------------------------------------------
-- lijst gemeenten per afdeling, regionale en land (aanmaak temptabel + INSERT)
---------------------------------------------------------------------
DROP TABLE IF EXISTS marketing._AV_temp_lijstgemeentenperafdeling;

CREATE TABLE marketing._AV_temp_lijstgemeentenperafdeling 
(land TEXT, gemeente TEXT, postcode TEXT, id NUMERIC, partner_id NUMERIC, afdeling TEXT, regionale TEXT, provincie TEXT
);
SELECT * FROM marketing._AV_temp_lijstgemeentenperafdeling ORDER BY gemeente;

INSERT INTO marketing._AV_temp_lijstgemeentenperafdeling (
	SELECT c.name land, cc.name gemeente, cc.zip postcode, cc.id, COALESCE(ocr.partner_id,0) partner_id, COALESCE(p.name,'') afdeling, r.name regionale,
		CASE
			WHEN c.id = 21 AND substring(cc.zip from '[0-9]+')::numeric BETWEEN 1000 AND 1299 THEN 'Brussel' 
			WHEN c.id = 21 AND (substring(cc.zip from '[0-9]+')::numeric BETWEEN 1500 AND 1999 OR substring(cc.zip from '[0-9]+')::numeric BETWEEN 3000 AND 3499) THEN 'Vlaams Brabant'
			WHEN c.id = 21 AND substring(cc.zip from '[0-9]+')::numeric BETWEEN 2000 AND 2999  THEN 'Antwerpen' 
			WHEN c.id = 21 AND substring(cc.zip from '[0-9]+')::numeric BETWEEN 3500 AND 3999  THEN 'Limburg' 
			WHEN c.id = 21 AND substring(cc.zip from '[0-9]+')::numeric BETWEEN 8000 AND 8999  THEN 'West-Vlaanderen' 
			WHEN c.id = 21 AND substring(cc.zip from '[0-9]+')::numeric BETWEEN 9000 AND 9999  THEN 'Oost-Vlaanderen' 
			WHEN c.id = 21 THEN 'Wallonië'
			WHEN c.id = 166 THEN 'Nederland'
			WHEN NOT(c.id IN (21,166)) THEN 'Buitenland niet NL'
			ELSE 'andere'
		END AS provincie
	FROM res_country c 
		JOIN res_country_city cc ON c.id = cc.country_id
		LEFT OUTER JOIN res_organisation_city_rel ocr ON cc.id = ocr.zip_id
		--JOIN res_country_city_street ccs ON cc.id = ccs.city_id
		LEFT OUTER JOIN res_partner p ON p.id = ocr.partner_id
		LEFT OUTER JOIN res_partner r ON p.partner_up_id = r.id
	WHERE c.id = 21
	);
---------------------------------------------------------------------	
DROP TABLE IF EXISTS marketing._AV_temp_aantallenpergemeente;

CREATE TABLE marketing._AV_temp_aantallenpergemeente 
(ID NUMERIC, gemeente TEXT, postcode NUMERIC, provincie TEXT, afdeling TEXT, afdeling_eigen_keuze TEXT, land TEXT);

SELECT * FROM marketing._AV_temp_aantallenpergemeente;
-- INSERT of manueel opladen
INSERT INTO marketing._AV_temp_aantallenpergemeente (
	(SELECT	DISTINCT--COUNT(p.id) _aantal, now()::date vandaag
		p.id database_id, 
		CASE 
			WHEN c.id = 21 THEN cc.name ELSE p.city 
		END woonplaats,
		CASE
			WHEN c.id = 21 AND p.crab_used = 'true' THEN cc.zip::numeric
			ELSE 0
		END postcode,
		CASE
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 1000 AND 1299 THEN 'Brussel' 
			WHEN p.country_id = 21 AND (substring(p.zip from '[0-9]+')::numeric BETWEEN 1500 AND 1999 OR substring(p.zip from '[0-9]+')::numeric BETWEEN 3000 AND 3499) THEN 'Vlaams Brabant'
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 2000 AND 2999  THEN 'Antwerpen' 
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 3500 AND 3999  THEN 'Limburg' 
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 8000 AND 8999  THEN 'West-Vlaanderen' 
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 9000 AND 9999  THEN 'Oost-Vlaanderen' 
			WHEN p.country_id = 21 THEN 'Wallonië'
			WHEN p.country_id = 166 THEN 'Nederland'
			WHEN NOT(p.country_id IN (21,166)) THEN 'Buitenland niet NL'
			ELSE 'andere'
		END AS provincie,
		COALESCE(COALESCE(a2.name,a.name),'onbekend') Afdeling,
		a2.name afdeling_eigen_keuze,
		c.name land	
	FROM 	myvar v, res_partner p
		--Voor de ontdubbeling veroorzaakt door meedere lidmaatschapslijnen
		LEFT OUTER JOIN (SELECT * FROM myvar v, membership_membership_line ml WHERE  ml.date_to BETWEEN v.startdatum and v.einddatum AND ml.membership_id IN (2,5,6,7,205,206,207,208)) ml ON ml.partner = p.id
		--land, straat, gemeente info
		JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		--afdeling vs afdeling eigen keuze
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
		--facturen info
		LEFT OUTER JOIN account_invoice_line il ON il.id = ml.account_invoice_line
		LEFT OUTER JOIN account_invoice i ON i.id = il.invoice_id
		--bank/mandaat info
		--door bank aan mandaat te linken en enkel de mandaat info te nemen ontdubbeling veroorzaakt door meerdere bankrekening nummers
		LEFT OUTER JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid') sm ON pb_partner_id = p.id
		--parnter info
		LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
	--=============================================================================
	WHERE p.active = 't'	--AND cc.active
		--we tellen voor alle actieve leden
		AND COALESCE(p.deceased,'f') = 'f' 
		--overledenen niet
		AND COALESCE(p.free_member,'f') = 'f'
		--gratis leden niet
		--AND p.membership_state IN ('paid','invoiced') -- **** uitschakelen voor jaarovergang ****
		--JAAROVERGANG HIERONDER
        AND p.membership_state IN ('paid','invoiced','waiting') -- jaarovergang; REJECTS reeds verwerkt
        AND p.membership_start < '2025-01-01' -- nieuwe leden na jaarovergang niet meetellen
        AND NOT(p.membership_state = 'waiting' AND p.membership_end < '2024-12-31')
        -- enkel voor fout in ERP met geannuleerde mandaten 2024
        AND NOT(p.membership_state = 'invoiced' AND COALESCE(sm.sm_id,0)=0)	
	--=============================================================================
	--GRATIS LEDEN TOEVOEGEN
	UNION ALL
	--=============================================================================
	SELECT	DISTINCT--COUNT(p.id) _aantal, now()::date vandaag
		p.id database_id, 
		CASE 
			WHEN c.id = 21 THEN cc.name ELSE p.city 
		END woonplaats,
		CASE
			WHEN c.id = 21 AND p.crab_used = 'true' THEN cc.zip::numeric
			ELSE 0
		END postcode,
		CASE
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 1000 AND 1299 THEN 'Brussel' 
			WHEN p.country_id = 21 AND (substring(p.zip from '[0-9]+')::numeric BETWEEN 1500 AND 1999 OR substring(p.zip from '[0-9]+')::numeric BETWEEN 3000 AND 3499) THEN 'Vlaams Brabant'
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 2000 AND 2999  THEN 'Antwerpen' 
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 3500 AND 3999  THEN 'Limburg' 
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 8000 AND 8999  THEN 'West-Vlaanderen' 
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 9000 AND 9999  THEN 'Oost-Vlaanderen' 
			WHEN p.country_id = 21 THEN 'Wallonië'
			WHEN p.country_id = 166 THEN 'Nederland'
			WHEN NOT(p.country_id IN (21,166)) THEN 'Buitenland niet NL'
			ELSE 'andere'
		END AS provincie,		
		COALESCE(COALESCE(a2.name,a.name),'onbekend') Afdeling,
		a2.name afdeling_eigen_keuze,			
		c.name land
	FROM 	myvar v, res_partner p
		--land, straat, gemeente info
		JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		--herkomst lidmaatschap
		LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
		--aangemaakt door 
		JOIN res_users u ON u.id = p.create_uid
		--afdeling vs afdeling eigen keuze
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
		--bank/mandaat info
		--door bank aan mandaat te linken en enkel de mandaat info te nemen ontdubbeling veroorzaakt door meerdere bankrekening nummers
		LEFT OUTER JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid') sm ON pb_partner_id = p.id
		--aanspreking
		LEFT OUTER JOIN res_partner_title pt ON p.title = pt.id
		--parnter info
		--LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
		LEFT OUTER JOIN res_partner p6 ON p.relation_partner_id = p6.id
		--wervend lid
		LEFT OUTER JOIN res_partner p2 ON p.recruiting_member_id = p2.id
		--wervende organisatie
		LEFT OUTER JOIN res_partner p5 ON p.recruiting_organisation_id = p5.id
	--=============================================================================
	WHERE 	p.active = 't'	--AND cc.active
		--we tellen voor alle actieve leden
		AND COALESCE(p.deceased,'f') = 'f' 
		--overledenen niet
		AND COALESCE(p.free_member,'f') = 't'
	));	
-------------------------------------------------------------------------------
-- Densiteit per gemeente
-------------------------------------------------------------------------------
SELECT postcode, gemeente, aantal_erp, aantal_huishoudens, (aantal_erp/aantal_huishoudens)*100 densiteit 
FROM	(SELECT postcode, gemeente, COUNT(ID) aantal_erp FROM marketing._AV_temp_aantallenpergemeente WHERE land = 'Belgium' GROUP BY postcode, gemeente ORDER BY postcode) erp
	JOIN
	(SELECT cd_zip_, SUM(totaal_huishoudens) aantal_huishoudens FROM myvar v, marketing._m_so_huishoudensvolgenstypeperpostcode WHERE jaar = v.vorigjaar GROUP BY cd_zip_, jaar ORDER BY cd_zip_) bestat
	ON erp.postcode = bestat.cd_zip_
-------------------------------------------------------------------------------
-- Densiteit per provincie
-------------------------------------------------------------------------------
SELECT erp.provincie, SUM(erp.aantal_erp) aantal_erp, SUM(bestat.aantal_huishoudens) aantal_huishoudens, 
	SUM(erp.aantal_erp)/SUM(bestat.aantal_huishoudens)*100 densiteit  
FROM (SELECT postcode, provincie, COUNT(ID) aantal_erp FROM marketing._AV_temp_aantallenpergemeente WHERE land = 'Belgium' GROUP BY postcode, provincie ORDER BY postcode) erp
	JOIN
	(SELECT jaar, cd_zip_, totaal_huishoudens aantal_huishoudens FROM myvar v, marketing._m_so_huishoudensvolgenstypeperpostcode WHERE jaar = v.vorigjaar ORDER BY cd_zip_) bestat
	ON erp.postcode = bestat.cd_zip_
GROUP BY erp.provincie
-------------------------------------------------------------------------------
-- Densiteit per afdeling
-- - met correcties
-- - correcties voor Antwerpen 
--   SELECT DISTINCT gemeente, postcode FROM marketing._AV_temp_aantallenpergemeente WHERE gemeente = 'Antwerpen';
-------------------------------------------------------------------------------
SELECT afdeling, aantal_erp, aantal_huishoudens, (aantal_erp/aantal_huishoudens)*100 densiteit
FROM
	(SELECT regdef.afdeling, 
		SUM(erp.aantal_erp) aantal_erp, 
		SUM(belstat.aantal_huishoudens) aantal_huishoudens
		--SUM(erp.aantal_erp)/SUM(bestat.aantal_huishoudens)*100 densiteit  
	FROM (SELECT postcode::numeric, COUNT(ID) aantal_erp FROM marketing._AV_temp_aantallenpergemeente WHERE land = 'Belgium' GROUP BY postcode ORDER BY postcode) erp
		JOIN
		(SELECT cd_zip_, totaal_huishoudens aantal_huishoudens FROM myvar v, marketing._m_so_huishoudensvolgenstypeperpostcode WHERE jaar = v.vorigjaar ORDER BY cd_zip_) belstat
		ON erp.postcode = belstat.cd_zip_
		JOIN
		(SELECT DISTINCT postcode::numeric, partner_id, afdeling FROM marketing._AV_temp_lijstgemeentenperafdeling ORDER BY postcode) regdef
		ON erp.postcode::numeric = regdef.postcode
	--WHERE regdef.afdeling IN ('Natuurpunt Dendermonding','Natuurpunt Scheldeland','Natuurpunt ''s Heerenbosch','Natuurpunt Antwerpen Stad','Natuurpunt De Wielewaal','Natuurpunt Schijnbeemden')
	GROUP BY regdef.afdeling
	ORDER BY regdef.afdeling) aantal
-------------------------------------------------------------------------------
-- Densiteit per Regionaal Samenwerkingsverband (Regionale)
-- - zelfde logica als 'densiteit per afdeling' met zelfde correcties
-- - enkel Group By aangepast naar 'GROUP BY regdef.regionale' (en daarvoor [regionale] toegevoegd aan SELECT van [regdef]
-------------------------------------------------------------------------------
SELECT regionale, SUM(aantal_erp) aantal_erp, SUM(aantal_huishoudens) aantal_huishoudens, (SUM(aantal_erp)/SUM(aantal_huishoudens))*100 densiteit
FROM
	(SELECT regdef.afdeling, regdef.regionale,
		SUM(erp.aantal_erp) aantal_erp, 
		SUM(belstat.aantal_huishoudens) aantal_huishoudens
		--SUM(erp.aantal_erp)/SUM(bestat.aantal_huishoudens)*100 densiteit  
	FROM (SELECT postcode::numeric, COUNT(ID) aantal_erp FROM marketing._AV_temp_aantallenpergemeente WHERE land = 'Belgium' GROUP BY postcode ORDER BY postcode) erp
		JOIN
		(SELECT cd_zip_, totaal_huishoudens aantal_huishoudens FROM myvar v, marketing._m_so_huishoudensvolgenstypeperpostcode WHERE jaar = v.vorigjaar ORDER BY cd_zip_) belstat
		ON erp.postcode = belstat.cd_zip_
		JOIN
		(SELECT DISTINCT postcode::numeric, partner_id, afdeling, regionale FROM marketing._AV_temp_lijstgemeentenperafdeling ORDER BY postcode) regdef
		ON erp.postcode::numeric = regdef.postcode
	--WHERE regdef.afdeling IN ('Natuurpunt Dendermonding','Natuurpunt Scheldeland','Natuurpunt ''s Heerenbosch','Natuurpunt Antwerpen Stad','Natuurpunt De Wielewaal','Natuurpunt Schijnbeemden')
	GROUP BY regdef.afdeling, regdef.regionale
	ORDER BY regdef.afdeling) aantal	
GROUP BY regionale	
--------------------------------------------------------------
-- aantallen correctie ter referentie
--------------------------------------------------------------
/*
SELECT COUNT(ID), afdeling, afdeling_eigen_keuze 
FROM marketing._AV_temp_aantallenpergemeente 
WHERE LOWER(afdeling) LIKE '%scheldeland' AND LOWER(afdeling_eigen_keuze) LIKE '%dendermonding' AND postcode = '9290' 
	OR LOWER(afdeling) = 'natuurpunt dendermonding' AND LOWER(afdeling_eigen_keuze) = 'natuurpunt ''s heerenbosch' AND postcode = '9200' 
	OR afdeling = 'Natuurpunt Schijnbeemden' AND afdeling_eigen_keuze = 'Natuurpunt Antwerpen Stad' AND postcode = '2140' 
	OR LOWER(afdeling) = 'natuurpunt schijnbeemden' AND LOWER(afdeling_eigen_keuze) = 'natuurpunt de wielewaal' AND postcode = '2520' 
GROUP BY afdeling, afdeling_eigen_keuze
*/
--------------------------------------------------------------
-- Correcties Antwerpen
--------------------------------------------------------------
/*
SELECT * FROM _AV_temp_huishoudensvolgenstypepergemeente WHERE refnis = 'Antwerpen'

SELECT ((SELECT COUNT(ID) FROM marketing._AV_temp_aantallenpergemeente WHERE gemeente = 'Antwerpen')*(1-0.161)) x;
SELECT ((SELECT totaal_private_huishoudens FROM _AV_temp_huishoudensvolgenstypepergemeente WHERE refnis = 'Antwerpen')*(1-0.135)) x;
Natuurpunt Antwerpen Noord vzw: 	0,161
Natuurpunt Schijnbeemden: 		0,231
Natuurpunt Wase Linkerscheldeoever: 	0,034
Natuurpunt Zuidrand Antwerpen:		0,078
Natuurpunt Antwerpen Stad: 		0,381
Natuurpunt Hobokense Polder vzw: 	0,135
*/