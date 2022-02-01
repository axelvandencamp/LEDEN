--=================================================================
-- aanmaak temp tabel "_AV_temp_aantalperAfd"
-- !!!! MANUEEL OPLADEN !!!! data aantal per afdeling
-- aanmaak temp tavbel "_AV_temp_LEDENcijfersperafdeling"
-- Uitval + % Uitval
-- Nieuwe leden
-- Huidig aantal leden
-- Groei aantal leden
-- Leden aangebracht
--=================================================================
--SET VARIABLES
DROP TABLE IF EXISTS _AV_myvar;
CREATE TEMP TABLE _AV_myvar 
	(startdatum DATE, einddatum DATE, vorigjaar NUMERIC, ledenaantal_vorigjaar NUMERIC);

INSERT INTO _AV_myvar VALUES(	'2022-01-01',	--startdatum
				'2023-12-31',	--einddatum
				2021,		--vorigjaar
				133094);	--ledenaantal_vorigjaar
				
SELECT * FROM _AV_myvar;
--====================================================================
--CREATE TMP TABLE
/*"marketing._m_so_aantalperAfdperJaar" vaste tabel; niet telkens meer updaten, enkel bij jaarovergan cijfers voorbije jaar toevoegen;
----------
-- --tabel NOOIT droppen!!!-- DROP TABLE IF EXISTS marketing._m_so_aantalperAfdperJaar;
CREATE TABLE marketing._m_so_aantalperAfdperJaar 
	(jaar INTEGER, id INTEGER, afdeling TEXT, aantal NUMERIC);

--!!!! MANUEEL OPLADEN (delimiter "|")!!!!--
--"S:\Ledenadministratie\Databeheer\Upld\LEDEN per afdeling 2020.csv (YYYY-1)"
				
SELECT * FROM marketing._m_so_aantalperAfdperJaar ORDER BY afdeling;
INSERT INTO marketing._m_so_aantalperAfdperJaar VALUES(2020,355934,'Natuurpunt Laakdal',0);

SELECT id, name naam FROM res_partner WHERE organisation_type_id = 1 ORDER BY name
*/
--====================================================================
--CREATE TMP TABLE
--/*
DROP TABLE IF EXISTS marketing._AV_temp_LEDENcijfersperafdeling;
CREATE TABLE marketing._AV_temp_LEDENcijfersperafdeling 
	(afd_id INTEGER, afdeling TEXT, "aantal_Y-1" NUMERIC, uitval NUMERIC, uitval_perc NUMERIC, nieuwe_leden NUMERIC, aantal_leden NUMERIC, groei NUMERIC, leden_aangebracht NUMERIC);

SELECT * FROM marketing._AV_temp_LEDENcijfersperafdeling ORDER BY afdeling;
--*/
--====================================================================
-- Huidig aantal leden
----------------------
INSERT INTO marketing._AV_temp_LEDENcijfersperafdeling 
	(SELECT COALESCE(a2.id,a.id) afd_id, COALESCE(COALESCE(a2.name,a.name),'onbekend') Afdeling,
	 	0,0,0,0,COUNT(DISTINCT p.id) aantal, 0,0
	FROM _AV_myvar v, res_partner p
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
	WHERE p.active AND p.membership_state IN ('paid','invoiced','free')
		--AND p.membership_start < '2021-01-01' --JAAROVERGANG
		--AND p.membership_start >= v.startdatum
		--AND COALESCE(a2.id,a.id) = 248516
	GROUP BY COALESCE(a2.id,a.id), COALESCE(COALESCE(a2.name,a.name),'onbekend'));
--====================================================================
--Uitval + % Uitval
-------------------
UPDATE marketing._AV_temp_LEDENcijfersperafdeling T1
SET "aantal_Y-1" = SQ1.aantal, uitval = SQ1.uitval, uitval_perc = SQ1.uitval_perc
FROM (SELECT COALESCE(a2.id,a.id) afd_id,  
		afd.aantal,
		COUNT(DISTINCT p.id) uitval,
		COUNT(DISTINCT p.id)/afd.aantal uitval_perc
	FROM _AV_myvar v, res_partner p
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
		LEFT OUTER JOIN marketing._m_so_aantalperAfdperJaar afd ON afd.id = COALESCE(a2.id,a.id) AND afd.aantal <> 0
	WHERE afd.jaar = v.vorigjaar
		AND p.membership_end = (v.startdatum + INTERVAL 'day -1')::date
		AND p.membership_state <> 'canceled'
	GROUP BY COALESCE(a2.id,a.id), afd.aantal) SQ1
WHERE T1.afd_id = SQ1.afd_id;
--====================================================================
-- Nieuwe leden
---------------
UPDATE marketing._AV_temp_LEDENcijfersperafdeling T1
SET nieuwe_leden = SQ1.aantal
FROM (SELECT COUNT(DISTINCT p.id) aantal, COALESCE(a2.id,a.id) afd_id
	FROM _AV_myvar v, res_partner p
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
	WHERE p.membership_state IN ('paid','invoiced','free')
		AND p.membership_start >= v.startdatum
		--AND p.membership_start < '2021-01-01' --JAAROVERGANG
	GROUP BY COALESCE(a2.id,a.id)) SQ1
WHERE T1.afd_id = SQ1.afd_id;

--====================================================================
-- groei aantal leden
---------------------
UPDATE marketing._AV_temp_LEDENcijfersperafdeling T1
SET groei = SQ1.aantal
FROM (SELECT (aantal_leden-"aantal_Y-1") aantal, afd_id FROM marketing._AV_temp_LEDENcijfersperafdeling) SQ1
WHERE T1.afd_id = SQ1.afd_id;
--====================================================================
-- aangebrachte leden
---------------------
UPDATE marketing._AV_temp_LEDENcijfersperafdeling T1
SET leden_aangebracht = SQ1.aantal 
FROM (SELECT COUNT(DISTINCT p.id) aantal, COALESCE(p.recruiting_organisation_id,0) afd_id
	FROM _AV_myvar v, res_partner p
		--LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		--LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
	WHERE p.membership_state IN ('paid','invoiced','free')
	  AND p.membership_start >= v.startdatum
	  --AND p.membership_start < '2021-01-01' --JAAROVERGANG
	GROUP BY p.recruiting_organisation_id) SQ1
WHERE T1.afd_id = SQ1.afd_id;
--====================================================================
SELECT * FROM marketing._AV_temp_LEDENcijfersperafdeling ORDER BY afdeling;
