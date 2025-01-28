----------------------------------------------------------------------
-- enkel lijnen met betaald lidmaatschapsproduct
-- - late hernieuwers
----------------------------------------------------------------------
SELECT SQ1.*, p.membership_start, 
	COALESCE(mm1.name,'') tijdschrift_1, COALESCE(mm2.name,'') tijdschrift_2,
	sq2.voornaam, sq2.achternaam, sq2.building, sq2.huisnummer, sq2.bus, sq2.postcode, sq2.woonplaats, sq2.postbus, sq2.land
FROM 	res_partner p
	JOIN
	(
	SELECT /*ml.id ml_id,*/ ml.partner partner_id, 
		ml.date_from, LAG(ml.date_from,1,ml.date_from) OVER (PARTITION BY ml.partner ORDER BY ml.date_to ASC) previous_date_from,
		ml.date_to, LAG(ml.date_to,1,ml.date_to) OVER (PARTITION BY ml.partner ORDER BY ml.date_to ASC) previous_date_to,
		DATE_PART('YEAR',AGE(ml.date_from,(LAG(ml.date_to,1,ml.date_to) OVER (PARTITION BY ml.partner ORDER BY ml.date_to ASC)))) AGEY_from_vs_prevto,
		DATE_PART('MONTH',AGE(ml.date_from,LAG(ml.date_to,1,ml.date_to) OVER (PARTITION BY ml.partner ORDER BY ml.date_to ASC))) AGEM_from_vs_prevto,
		ml.state, pp.name_template
	FROM membership_membership_line ml
		JOIN product_product pp ON pp.id = ml.membership_id
	WHERE pp.membership_product
		AND ml.state = 'paid'
	ORDER BY ml.partner, ml.date_from DESC	
	) SQ1 ON SQ1.partner_id = p.id
	JOIN marketing._crm_partnerinfo() sq2 ON sq2.partner_id = p.id
	--tijdschrift 1 en/of - 2
	LEFT OUTER JOIN mailing_mailing mm1 ON p.periodical_1_id = mm1.id
	LEFT OUTER JOIN mailing_mailing mm2 ON p.periodical_2_id = mm2.id

WHERE SQ1.date_from BETWEEN '2024-09-01' AND '2024-12-31'
	AND p.membership_start < '2024-01-01'
	AND SQ1.previous_date_to < '2024-01-01'
	AND SQ1.agey_from_vs_prevto < 5
	--AND SQ1.agey_from_vs_prevto >= 5

/*
WHERE SQ1.date_from BETWEEN '2017-09-01' AND '2017-12-31'
	AND p.membership_start < '2017-01-01'
	AND SQ1.previous_date_to < '2017-01-01'
	AND SQ1.agey_from_vs_prevto = 0
*/
-----------------------------------------------
-- SUBQUERIES:
--------------
-- sq1: 2 recentste lidmaatschapslijnen ophalen
-- sq2: 1 lijn per partner met datediff tussen 2 lml's
-- sq3: _crm_partner_info
-----------------------------------------------
DROP TABLE IF EXISTS _AV_myvar;
CREATE TEMP TABLE _AV_myvar 
	(startdatum date, einddatum date, betaaldatum date
	 );

INSERT INTO _AV_myvar VALUES(date_trunc('year', now()),	--startdatum
				cast(date_trunc('year', now()) + '1 year'::interval as date) - 1,	--einddatum
				date_trunc('year', now()) + '6 month'::interval	--betaaldatum
				);

		
				
SELECT (date_trunc('year', now()) + '6 month'::interval)::date FROM _AV_myvar;

SELECT DATE_PART('YEAR', now()::date) - v.jaartal FROM _AV_myvar v
-------------------------------------------------------------------
SELECT sq2.*, p.membership_pay_date, p.membership_end recentste_einddatum_lidmaatschap, 
		CASE WHEN u.login = 'apiuser' THEN 'via website'
			WHEN u.login IN ('axel','vera','kristienv') THEN 'ledenadministratie'
			ELSE 'andere' END aangemaakt_door, sq3.*
FROM	(
	SELECT sq1.partner, max(sq1.id) ml_id, max(sq1.date_from) date_from_1, min(sq1.date_to) date_to_onderbreking,
		DATE_PART('YEAR', AGE(max(sq1.date_from), min(sq1.date_to))) date_diff
	FROM	(
		SELECT ml.id, ml.partner, ml.date_from, ml.date_to, ml.state, pp.name_template,
			ROW_NUMBER() OVER (PARTITION BY ml.partner ORDER BY ml.id DESC) AS r
		FROM membership_membership_line ml
			JOIN product_product pp ON pp.id = ml.membership_id
		WHERE pp.membership_product
			AND ml.state = 'paid' --AND ml.partner = 295277
			--AND ml.date_to > '2014-12-31'
		GROUP BY ml.partner, ml.id, ml.date_from, ml.date_to, ml.state, pp.name_template
		ORDER BY ml.id DESC
		) sq1
		JOIN res_partner p ON p.id = sq1.partner
	WHERE sq1.r <= 2
	GROUP BY sq1.partner
	) sq2
	JOIN res_partner p ON p.id = sq2.partner
	JOIN _crm_partnerinfo() sq3 ON sq3.partner_id = p.id
	JOIN res_users u ON u.id = p.create_uid
WHERE sq2.date_diff >= 1 --BETWEEN 1 AND 5
	AND p.membership_pay_date >= '2020-07-01'
	AND p.membership_end = '2020-12-31'