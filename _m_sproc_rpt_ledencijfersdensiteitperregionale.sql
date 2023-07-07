-- DROP FUNCTION marketing._m_sproc_rpt_ledencijfersdensiteitperregionale(text, date, date,integer, integer)

CREATE OR REPLACE FUNCTION marketing._m_sproc_rpt_ledencijfersdensiteitperregionale(
	--IN job_id integer,
	IN prm_periode text,
	IN prm_startdatum date,
	IN prm_einddatum date,
	IN prm_vorigjaar integer DEFAULT 2022,
	IN prm_sproc_naam integer DEFAULT 1,
	---
	OUT reg_id integer,
	OUT regionale character varying,
	OUT aantal_erp numeric,
	OUT aantal_huishoudens numeric,
	OUT densiteit numeric
	)
  RETURNS SETOF record AS
$BODY$
DECLARE 
	v_TS timestamp without time zone;
	v_jobid integer;
	v_startdatum date;
	v_einddatum date;
	
BEGIN	
	SELECT now()::timestamp without time zone INTO v_TS;
	--SELECT DATE_PART('year',now()::date) INTO v_huidigjaar;
	INSERT INTO marketing._m_master_jobs (datum, sproc_id) VALUES (v_TS, prm_sproc_naam);
	SELECT mj.id FROM marketing._m_master_jobs mj WHERE datum = v_TS INTO v_jobid;
	--/*
	SELECT
	CASE 
		WHEN prm_periode = 'CST' THEN prm_startdatum
		ELSE marketing._crm_startdatum(prm_periode)
	END INTO v_startdatum;
	SELECT
	CASE 
		WHEN prm_periode = 'CST' THEN prm_einddatum
		ELSE marketing._crm_einddatum(prm_periode)
	END INTO v_einddatum;	
	
	-- RETURN QUERY externe logica
		
	RETURN QUERY
	--====================================================================
	SELECT sq3.reg_id, sq3.regionale, SUM(sq3.aantal_erp) aantal_erp, SUM(sq3.aantal_huishoudens) aantal_huishoudens, (SUM(sq3.aantal_erp)/SUM(sq3.aantal_huishoudens))*100 densiteit
	--SELECT sq3.afd_id, sq3.afdeling, sq3.aantal_erp, sq3.aantal_huishoudens, (sq3.aantal_erp/sq3.aantal_huishoudens)*100 densiteit
	FROM
		(SELECT regdef.afdeling, regdef.afd_id, regdef.regionale, regdef.reg_id,
			SUM(erp.aantal_erp) aantal_erp, 
			SUM(belstat.aantal_huishoudens) aantal_huishoudens
		FROM (SELECT sq1.postcode::numeric, COUNT(sq1.partner_id) aantal_erp FROM 



			  (SELECT DISTINCT
					p.id partner_id, 
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
				FROM res_partner p
					JOIN res_country c ON p.country_id = c.id
					LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
					LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
					LEFT OUTER JOIN res_partner a ON p.department_id = a.id
					LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
				--=============================================================================
				WHERE p.active = 't' AND COALESCE(p.deceased,'f') = 'f' AND p.membership_state IN ('paid','invoiced','free') 
			   ) sq1



			  WHERE land = 'Belgium' GROUP BY sq1.postcode ORDER BY sq1.postcode) erp
			JOIN
			(SELECT cd_zip_, totaal_huishoudens aantal_huishoudens FROM marketing._m_so_huishoudensvolgenstypeperpostcode WHERE jaar = prm_vorigjaar ORDER BY cd_zip_) belstat
			ON erp.postcode = belstat.cd_zip_
			JOIN
			(SELECT DISTINCT sq2.postcode::numeric, sq2.partner_id, sq2.afdeling, sq2.afd_id, sq2.regionale, sq2.reg_id FROM 




				(SELECT c.name land, cc.name gemeente, cc.zip postcode, cc.id, COALESCE(ocr.partner_id,0) partner_id, COALESCE(p.name,'onbekend') afdeling, p.id afd_id, COALESCE(r.name,'onbekend') regionale, r.id reg_id,
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
					LEFT OUTER JOIN res_partner p ON p.id = ocr.partner_id
					LEFT OUTER JOIN res_partner r ON p.partner_up_id = r.id
				WHERE c.id = 21
				) sq2



			 ORDER BY sq2.postcode::numeric) regdef
			ON erp.postcode::numeric = regdef.postcode
		GROUP BY regdef.reg_id, regdef.regionale, regdef.afd_id, regdef.afdeling
		ORDER BY regdef.afdeling) sq3
	GROUP BY sq3.reg_id, sq3.regionale;		
END;

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION marketing._m_sproc_rpt_ledencijfersdensiteitperregionale(text, date, date,integer, integer)
  OWNER TO axelvandencamp;
GRANT EXECUTE ON FUNCTION marketing._m_sproc_rpt_ledencijfersdensiteitperregionale(text, date, date,integer, integer) TO public;
GRANT EXECUTE ON FUNCTION marketing._m_sproc_rpt_ledencijfersdensiteitperregionale(text, date, date,integer, integer) TO axelvandencamp;
GRANT EXECUTE ON FUNCTION marketing._m_sproc_rpt_ledencijfersdensiteitperregionale(text, date, date,integer, integer) TO readonly;

--  SELECT * FROM marketing._m_sproc_rpt_ledencijfersdensiteitperregionale('CST', '2023-01-01', '2024-12-31',2022, 1)
--  DROP TABLE IF EXISTS marketing._AV_temp_LEDENcijfersperafdeling;
