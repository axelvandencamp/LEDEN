--------------------------------------------------------------------------------
-- AANPASSINGEN:
-- -------------
-- 12/09/2017: onderbreking wordt vastgesteld na 9 maanden ipv 1 jaar
-- dd/09/2017: start_na_onderbreking (numeric - jaartal) toegevoegd
--------------------------------------------------------------------------------
DROP TABLE IF EXISTS tempLEDENANALYSE;

CREATE TEMP TABLE tempLEDENANALYSE (
	partner_id numeric, 
	ml_id numeric, 
	date_from date, 
	jaar_start numeric, 
	date_to date, 
	jaar_einde numeric,
	start_onderbreking numeric,
	onderbreking numeric,
	start_na_onderbreking numeric,
	duurtijd numeric, 
	eerste_lidmaatschap numeric, 
	jaar_start_1 numeric,  
	laatste_lidmaatschap numeric, 
	jaar_einde_L numeric, 
	via_afdeling numeric, 
	Kustcampagne numeric,
	Zomer_Antw numeric,
	Face_To_Face numeric,
	Geschenk numeric,
	Website numeric,
	Partners numeric,
	BC numeric,
	B_en_F numeric,
	MWA numeric,
	MA numeric,
	Andere numeric, 
	Belactie numeric,
	herkomst text,
	domi numeric
	);
-----------------------------------------------------------------------------------------------------------------------------------
-- structuur subqueries:
-- - SQ3
-- -   SQ1 (ophalen van alle lidmaatschapslijnen)
-- -   SQ2 (ophalen van 1e lidmaatschapslijn per partner)
-- -   SQ5 (ophalen van laatste lidmaatschapslijn per partner)
-- -   wervende organisatie
-- -   herkomst lidmaatschap
-- -   mandaat info
-- - SQ4
-- -   SQ4b (toewijzen "start_onderbreking": geen onderbreking: 1900; wel onderbreking: jaartal einddatum vorige lidmaatschapslijn)
-- -     SQ4a (max"start_onderbreking": <> 1900 indien onderbreking voorkomt; op basis hiervan krijgt "onderbreking" een waarde)
-----------------------------------------------------------------------------------------------------------------------------------
INSERT into tempLEDENANALYSE
	(SELECT SQ3.partner_id, SQ3.ml_id, SQ3.date_from, date_part('year',SQ3.date_from) jaar_start, SQ3.date_to, date_part('year',SQ3.date_to) jaar_einde,
		SQ4.start_onderbreking,
		CASE
			WHEN SQ4.start_onderbreking = 1900 THEN 0
			WHEN SQ4.start_onderbreking < date_part('year',SQ3.date_to) THEN 1 ELSE 0
		END onderbreking,
		SQ4.start_na_onderbreking,
		SQ3.duurtijd, SQ3.eerste_lidmaatschap, SQ3.jaar_start_1,  SQ3.laatste_lidmaatschap, SQ3.jaar_einde_L, SQ3.via_afdeling, 
		SQ3.Kustcampagne, SQ3.Zomer_Antw, SQ3.Face_To_Face, SQ3.Geschenk, SQ3.Website, SQ3.Partners, SQ3.BC, SQ3.B_en_F, SQ3.MWA, SQ3.MA, SQ3.Andere, 
		SQ3.Belactie, SQ3.herkomst, SQ3.domi	
	FROM
		(
		--------------------------------------------------------------------------------
		-- SQ3: nodig om de "onderbreking" mee te nemen naar volgende lijnen
		--------------------------------------------------------------------------------
		SELECT SQ1.partner_id, SQ1.ml_id, SQ1.date_from, SQ1.date_to,
			LAG(SQ1.date_to,1,SQ1.date_from) OVER (PARTITION BY SQ1.partner_id ORDER BY SQ1.date_from) previous_date_to, --testwaarde
			--p.membership_start,
			--p.membership_end,
			CASE
				WHEN date_part('year',SQ1.date_from) = date_part('year',SQ1.date_to) AND date_part('month',age(SQ1.date_to,SQ1.date_from)) > 3 THEN 1
				ELSE date_part('year',age(SQ1.date_to,SQ1.date_from)) 
			END duurtijd,
			date_part('year',SQ1.date_from) test_yf,
			date_part('year',SQ1.date_to) test_yt,
			date_part('month',age(SQ1.date_to,SQ1.date_from)) test_m,
			CASE
				WHEN SQ1.ml_id = SQ2.ml_id THEN 1 ELSE 0
			END eerste_lidmaatschap,
			date_part('year',SQ2.ml_date_from) jaar_start_1,
			CASE
				WHEN SQ1.ml_id = SQ5.ml_id THEN 1 ELSE 0
			END laatste_lidmaatschap,
			date_part('year',SQ5.ml_date_to) jaar_einde_L,
			CASE
				WHEN COALESCE(p5.id,0) > 0 THEN 1 ELSE 0
			END via_afdeling,
			CASE
				WHEN COALESCE(moc.id,0) = 16 THEN 1 ELSE 0
			END Kustcampagne,
			CASE
				WHEN COALESCE(moc.id,0) = 2 THEN 1 ELSE 0
			END Zomer_Antw,
			CASE
				WHEN COALESCE(moc.id,0) IN (11,3) THEN 1 ELSE 0
			END Face_To_Face,
			CASE
				WHEN COALESCE(moc.id,0) = 9 THEN 1 ELSE 0
			END Geschenk,
			CASE
				WHEN COALESCE(moc.id,0) = 7 THEN 1 ELSE 0
			END Website,
			CASE
				WHEN COALESCE(moc.id,0) = 6 THEN 1 ELSE 0
			END Partners,
			CASE
				WHEN COALESCE(moc.id,0) = 8 THEN 1 ELSE 0
			END BC,
			CASE
				WHEN COALESCE(moc.id,0) = 4 THEN 1 ELSE 0
			END B_en_F,
			CASE
				WHEN COALESCE(moc.id,0) = 1 THEN 1 ELSE 0
			END MWA,
			CASE
				WHEN COALESCE(moc.id,0) = 18 THEN 1 ELSE 0
			END MA,
			CASE
				WHEN COALESCE(SQ6.partner_id,0) > 0 THEN 1 ELSE 0 
			END Belactie,
			CASE
				WHEN NOT(COALESCE(moc.id,0) IN (16,2,11,3,9,7,6,8,4,1,18)) THEN 1 ELSE 0
			END Andere,
			CASE
				WHEN COALESCE(moc.id,0) = 16 THEN 'Kust Campagne' 
				WHEN COALESCE(moc.id,0) = 2 THEN 'Zomer van Antwerpen' 
				WHEN COALESCE(moc.id,0) IN (11,3) THEN 'Face to Face'
				WHEN COALESCE(moc.id,0) = 9 THEN 'Geschenklidmaatschap'
				WHEN COALESCE(moc.id,0) = 7 THEN 'Website'
				WHEN COALESCE(moc.id,0) = 6 THEN 'Partners'
				WHEN COALESCE(moc.id,0) = 8 THEN 'Bezoekerscentrum'
				WHEN COALESCE(moc.id,0) = 4 THEN 'Beurzen en Festivals'
				WHEN COALESCE(moc.id,0) = 1 THEN 'Mailing warme adressen'
				WHEN COALESCE(moc.id,0) = 18 THEN 'Mailing adressen'
				--BELACTIE nog toe te voegen
				ELSE 'Andere'
			END Herkomst,
			CASE
				WHEN COALESCE(sm.sm_id,0) > 0 THEN 1 ELSE 0
			END DOMI
		FROM 
			--------------------------------------------------------------------
			-- SQ1: ophalen van alle lidmaatschapslijnen
			--------------------------------------------------------------------
			(SELECT ml.partner partner_id, ml.id ml_id, ml.date_from, ml.date_to, recruiting_organisation_id, membership_origin_id
			FROM res_partner p
				INNER JOIN membership_membership_line ml ON p.id = ml.partner
				INNER JOIN product_product pp ON ml.membership_id = pp.id
			WHERE pp.membership_product --AND ml.partner = 160452
			ORDER BY ml.partner, ml.date_from
			) SQ1
			------------------------------------------------------------- SQ1 --
			INNER JOIN 
			--------------------------------------------------------------------
			-- SQ2: ophalen van 1e lidmaatschapslijn per partner
			--------------------------------------------------------------------
			(SELECT ml.partner partner_id, MIN(ml.id) ml_id, MIN(ml.date_from) ml_date_from
			FROM membership_membership_line ml
				INNER JOIN product_product pp ON ml.membership_id = pp.id
			WHERE pp.membership_product --AND ml.partner = 220646
			GROUP BY ml.partner
			) SQ2
			------------------------------------------------------------- SQ2 --
			ON SQ1.partner_id = SQ2.partner_id
			INNER JOIN 
			--------------------------------------------------------------------
			-- SQ5: ophalen van laatste lidmaatschapslijn per partner
			--------------------------------------------------------------------
			(SELECT ml.partner partner_id, MAX(ml.id) ml_id, MAX(ml.date_to) ml_date_to
			FROM membership_membership_line ml
				INNER JOIN product_product pp ON ml.membership_id = pp.id
			WHERE pp.membership_product --AND ml.partner = 220646
			GROUP BY ml.partner
			) SQ5
			------------------------------------------------------------- SQ5 --
			ON SQ1.partner_id = SQ5.partner_id
			LEFT OUTER JOIN
			--------------------------------------------------------------------
			-- SQ6: ophalen lidmaatschapslijnen met "bloem%" in Opmerkingen-veld
			--------------------------------------------------------------------
			(SELECT DISTINCT ml.partner partner_id
			FROM membership_membership_line ml
				INNER JOIN product_product pp ON ml.membership_id = pp.id
			WHERE LOWER(ml.remarks) LIKE '%bloem%' AND pp.membership_product --AND ml.partner = 220646
			GROUP BY ml.partner 
			) SQ6
			------------------------------------------------------------- SQ6 --
			ON SQ6.partner_id = SQ1.partner_id
			INNER JOIN res_partner p ON p.id = SQ1.partner_id
			--wervende organisatie
			LEFT OUTER JOIN res_partner p5 ON SQ1.recruiting_organisation_id = p5.id
			--herkomst lidmaatschap
			LEFT OUTER JOIN res_partner_membership_origin mo ON SQ1.membership_origin_id = mo.id
			LEFT OUTER JOIN res_partner_membership_origin_category moc ON moc.id = mo.membership_origin_category_id
			--mandaat info
			LEFT OUTER JOIN (SELECT pb.partner_id pb_partner_id, max(sm.id) sm_id FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid' GROUP BY pb.partner_id) sm ON pb_partner_id = SQ1.partner_id
		) SQ3
		------------------------------------------------------------------------- SQ3 --
		INNER JOIN
		-------------------------------------------------------------------------------------------
		-- SQ4: berekenen van het jaar van de onderbreking (jaar van einddatum voor onderbreking)
		-- - nemen van MAX van start_onderbreking (indien geen onderbreking alles 1900 en dus op 0)
		-- - door dit te linken kunnen we in SQ3 alle jaren volgend na onderbreking op 1 zetten
		-------------------------------------------------------------------------------------------
		(SELECT SQ4b.partner_id, max(SQ4b.start_onderbreking) start_onderbreking, max(SQ4b.start_na_onderbreking) start_na_onderbreking
		FROM
			(SELECT SQ4a.partner_id ,
				CASE
					WHEN date_part('year',age(SQ4a.date_from,(LAG(SQ4a.date_to,1,SQ4a.date_from) OVER (PARTITION BY SQ4a.partner_id ORDER BY SQ4a.date_from)))) 
						+ date_part('month',age(SQ4a.date_from,(LAG(SQ4a.date_to,1,SQ4a.date_from) OVER (PARTITION BY SQ4a.partner_id ORDER BY SQ4a.date_from))))/100 >= 0.08 
					THEN date_part('year',LAG(SQ4a.date_to,1,SQ4a.date_from) OVER (PARTITION BY SQ4a.partner_id ORDER BY SQ4a.date_from)) 
					ELSE 1900
				END start_onderbreking,
				CASE
					WHEN date_part('year',age(SQ4a.date_from,(LAG(SQ4a.date_to,1,SQ4a.date_from) OVER (PARTITION BY SQ4a.partner_id ORDER BY SQ4a.date_from)))) 
						+ date_part('month',age(SQ4a.date_from,(LAG(SQ4a.date_to,1,SQ4a.date_from) OVER (PARTITION BY SQ4a.partner_id ORDER BY SQ4a.date_from))))/100 >= 0.08 
					THEN date_part('year',SQ4a.date_from)
					ELSE 1900
				END start_na_onderbreking
				/*, date_part('year',age(SQ4a.date_from,(LAG(SQ4a.date_to,1,SQ4a.date_from) OVER (PARTITION BY SQ4a.partner_id ORDER BY SQ4a.date_from)))) 
				+ date_part('month',age(SQ4a.date_from,(LAG(SQ4a.date_to,1,SQ4a.date_from) OVER (PARTITION BY SQ4a.partner_id ORDER BY SQ4a.date_from))))/100 as test
				, SQ4a.date_from*/
			FROM (SELECT ml.partner partner_id, ml.id ml_id, ml.date_from, ml.date_to, recruiting_organisation_id, membership_origin_id
				FROM res_partner p
					INNER JOIN membership_membership_line ml ON p.id = ml.partner
					INNER JOIN product_product pp ON ml.membership_id = pp.id
				WHERE pp.membership_product --AND ml.partner = 106076
				ORDER BY ml.partner, ml.date_from
				) SQ4a
			--WHERE partner_id = 106076
			) SQ4b
		GROUP BY SQ4b.partner_id
		) SQ4 
		----------------------------------------------------------------------------------- Q4 --
		ON SQ3.partner_id = SQ4.partner_id);

--SELECT * FROM tempLEDENANALYSE WHERE partner_id IN (17319,17322)		

DROP TABLE IF EXISTS tempLEDENANALYSEbyPartner;

CREATE TEMP TABLE tempLEDENANALYSEbyPartner (
	partner_id NUMERIC, duurtijd NUMERIC, duurtijd_voor_onderbreking NUMERIC, duurtijd_na_onderbreking NUMERIC, start_onderbreking NUMERIC, start_na_onderbreking NUMERIC,
	/*date_from, jaar_start, date_to, jaar_einde,*/ jaar_start_1 NUMERIC, jaar_einde_L NUMERIC, 
	via_afdeling NUMERIC, /*Kustcampagne, Zomer_Antw, Face_To_Face, Geschenk, Website, Partners, BC, B_en_F, MWA, MA, Andere,*/ Belactie NUMERIC, herkomst TEXT, domi NUMERIC, ooit_domi NUMERIC, domi_laatste_eindat DATE);

INSERT INTO tempLEDENANALYSEbyPartner
	(SELECT partner_id, SUM(duurtijd) duurtijd, 0, 0, MAX(start_onderbreking) start_onderbreking, MAX(start_na_onderbreking) start_na_onderbreking,
		/*date_from, jaar_start, date_to, jaar_einde,*/ jaar_start_1, jaar_einde_L, 
		via_afdeling, /*Kustcampagne, Zomer_Antw, Face_To_Face, Geschenk, Website, Partners, BC, B_en_F, MWA, MA, Andere,*/ Belactie, herkomst, domi, 0, NULL
	FROM tempLEDENANALYSE
	GROUP BY partner_id, herkomst, via_afdeling, domi, belactie, jaar_start_1, jaar_einde_L);

--SELECT * FROM tempLEDENANALYSEbyPartner WHERE partner_id IN (17319,17322) LIMIT 10	

UPDATE tempLEDENANALYSEbyPartner la
SET duurtijd_voor_onderbreking = x.duurtijd
FROM (SELECT partner_id, SUM(duurtijd) duurtijd FROM tempLEDENANALYSE WHERE onderbreking = 0 GROUP BY partner_id) x 
WHERE la.partner_id = x.partner_id;

UPDATE tempLEDENANALYSEbyPartner la
SET duurtijd_na_onderbreking = x.duurtijd
FROM (SELECT partner_id, SUM(duurtijd) duurtijd FROM tempLEDENANALYSE WHERE onderbreking = 1 GROUP BY partner_id) x 
WHERE la.partner_id = x.partner_id;

UPDATE tempLEDENANALYSEbyPartner la
SET ooit_domi = 1, domi_laatste_eindat = x.last_debit_date
FROM (SELECT SQsm1.partner_id, sm.last_debit_date FROM
		(SELECT pb.partner_id, MAX(sm.id) sm_id
		FROM res_partner_bank pb 
		JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id 
		--WHERE pb.partner_id IN (17319,17322)
		GROUP BY pb.partner_id) SQsm1
	JOIN sdd_mandate sm ON sm.id = SQsm1.sm_id
	) x
WHERE la.partner_id = x.partner_id;
	




SELECT * FROM tempLEDENANALYSEbyPartner;

-----------------------------------------------------------------------------------
-- test queries
-----------------------------------------------------------------------------------
--/*
SELECT pb.partner_id, sm.id, sm.last_debit_date, sm.state 
FROM res_partner_bank pb 
JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id 
WHERE pb.partner_id IN (17319,17322)
ORDER BY pb.partner_id

SELECT SQsm1.partner_id, sm.last_debit_date FROM
	(SELECT pb.partner_id, MAX(sm.id) sm_id
	FROM res_partner_bank pb 
	JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id 
	--WHERE pb.partner_id IN (17319,17322)
	GROUP BY pb.partner_id) SQsm1
JOIN sdd_mandate sm ON sm.id = SQsm1.sm_id
WHERE SQsm1.partner_id IN (17319,17322)

 
SELECT DISTINCT(ml.remarks) FROM membership_membership_line ml WHERE LOWER(ml.remarks) LIKE 'bloem%' ORDER BY ml.remarks


SELECT ml.partner partner_id, --ml.id ml_id, ml.date_from, ml.date_to, recruiting_organisation_id, membership_origin_id,
	date_part('year',LAG(ml.date_to,1,ml.date_from) OVER (PARTITION BY ml.partner ORDER BY ml.date_from)) start_onderbreking
FROM res_partner p
	INNER JOIN membership_membership_line ml ON p.id = ml.partner
	INNER JOIN product_product pp ON ml.membership_id = pp.id
WHERE pp.membership_product
	AND date_part('year',age(ml.date_from,(LAG(ml.date_to,1,ml.date_from) OVER (PARTITION BY ml.partner ORDER BY ml.date_from)))) > 1
	AND ml.partner = 16896
GROUP BY ml.partner



SELECT SQ4a.partner_id , date_part('year',age(SQ4a.date_from,(LAG(SQ4a.date_to,1,SQ4a.date_from) OVER (PARTITION BY SQ4a.partner_id ORDER BY SQ4a.date_from)))) test,
	date_part('year',LAG(SQ4a.date_to,1,SQ4a.date_from) OVER (PARTITION BY SQ4a.partner_id ORDER BY SQ4a.date_from)) test_start,
	CASE
		WHEN date_part('year',age(SQ4a.date_from,(LAG(SQ4a.date_to,1,SQ4a.date_from) OVER (PARTITION BY SQ4a.partner_id ORDER BY SQ4a.date_from)))) >= 1 
		THEN date_part('year',LAG(SQ4a.date_to,1,SQ4a.date_from) OVER (PARTITION BY SQ4a.partner_id ORDER BY SQ4a.date_from)) 
		ELSE 1900
	END start_onderbreking
FROM (SELECT ml.partner partner_id, ml.id ml_id, ml.date_from, ml.date_to, recruiting_organisation_id, membership_origin_id
	FROM res_partner p
		INNER JOIN membership_membership_line ml ON p.id = ml.partner
		INNER JOIN product_product pp ON ml.membership_id = pp.id
	WHERE pp.membership_product AND ml.partner = 259890
	ORDER BY ml.partner, ml.date_from
	) SQ4a
WHERE partner_id = 259890


SELECT * FROM product_product WHERE membership_product
--*/
-----------------------------------------------------------------------------------
-- subquery voor selectie domi bij juiste lidmaatschapslijn: werkt nog niet correct
-----------------------------------------------------------------------------------
/*
SELECT p_id, ml_id, date_from, date_to, --sm_start, sm_end, 
	max(domi) domi
FROM (
	SELECT DISTINCT p.id p_id, ml.id ml_id, ml.date_from, ml.date_to, sm.sm_start, 
		CASE
			WHEN sm.sm_state = 'valid' THEN COALESCE(sm.sm_end,now()::date)
			WHEN sm.sm_state <> 'valid' THEN COALESCE(sm.sm_end,'1099-01-01')
		END sm_end,
		CASE
			WHEN sm.sm_start >= ml.date_from AND sm.sm_start > ml.date_to THEN 0
			WHEN sm.sm_start >= ml.date_from AND sm.sm_start < ml.date_to THEN 1
			WHEN sm.sm_start < ml.date_from AND CASE
								WHEN sm.sm_state = 'valid' THEN COALESCE(sm.sm_end,now()::date)
								WHEN sm.sm_state <> 'valid' THEN COALESCE(sm.sm_end,'1099-01-01')
							END > ml.date_from THEN 1
			ELSE 0
		END domi
	FROM res_partner p
		INNER JOIN membership_membership_line ml ON p.id = ml.partner
		LEFT OUTER JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.state sm_state, sm.signature_date sm_start, sm.last_debit_date sm_end FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id) sm ON pb_partner_id = p.id
	WHERE p.id = 16709
	ORDER BY date_from) SQ5
GROUP BY ml_id, date_from, date_to, p_id
ORDER BY date_from	
*/
