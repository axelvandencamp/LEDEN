--------------------------------------------------------
-- variabelen
--------------------------------------------------------
DROP TABLE IF EXISTS myvar;
SELECT 
	--'2016-12-31'::date AS cutoff_datum,
	'2024-01-01'::date AS startdatum_vorigjaar,
	'2024-12-31'::date AS einddatum_vorigjaar,
	'2025-01-01'::date AS startdatum,
	'2025-12-31'::date AS einddatum,  --naar volgend jaar verzetten vanaf 01/07
	'248514'::numeric AS afdeling --(aartselaar 248646; hobokense polder 248569; gent vzw 248514)
INTO TEMP TABLE myvar;
SELECT * FROM myvar;
--------------------------------------------------------

--------------------------------------------------------
--INSERT INTO temp_NietHernieuwden (	
SELECT DISTINCT p.id,
	p.membership_state status,
	p.create_date::date aanmaakdatum,
	--ml.create_date::date start_lidmaatschap,
	p.membership_start Lidmaatschap_startdatum, 
	p.membership_stop Lidmaatschap_einddatum, 
	p.membership_pay_date Betaaldatum, 
	p.membership_end Recentste_einddatum_lidmaatschap, 
	DATE_PART('YEAR',AGE(p.membership_end,p.membership_start)) duurtijd_j,
	p.membership_cancel p_opzegdatum, --opzegdatum 
	--ml.date_cancel ml_opzegdatum,
	--COALESCE(ml.date_cancel,p.membership_cancel) opzegdatum,
	--COALESCE(mcr.name,'onbekend') reden_opzeg,
	p.active
	--DATE_PART('YEAR',COALESCE(ml.date_cancel,p.membership_cancel)) opzeg_jaar,
	--DATE_PART('MONTH',COALESCE(ml.date_cancel,p.membership_cancel)) opzeg_maand,
	--DATE_PART('WEEK',COALESCE(ml.date_cancel,p.membership_cancel)) opzeg_week,
	--DATE_PART('DAY',COALESCE(ml.date_cancel,p.membership_cancel)) opzeg_dag
	-- herkomst (niet in default)
	, COALESCE(mo.name,'') herkomst
FROM	myvar v, res_partner p
	JOIN (SELECT MAX(ml.id) ml_id, partner FROM membership_membership_line ml JOIN product_product pp ON pp.id = ml.membership_id WHERE ml.state = 'paid' GROUP BY partner) ml1 ON ml1.partner = p.id
	JOIN membership_membership_line ml ON ml.id = ml1.ml_id
	--herkomst lidmaatschap
	LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
	--afdeling vs afdeling eigen keuze
	--LEFT OUTER JOIN res_partner a ON p.department_id = a.id
	--LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
	--regionale
	--LEFT OUTER JOIN res_partner r ON r.id = COALESCE(a2.partner_up_id,a.partner_up_id)
	--bank/mandaat info
	--door bank aan mandaat te linken en enkel de mandaat info te nemen ontdubbeling veroorzaakt door meerdere bankrekening nummers
	--LEFT OUTER JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, pb.bank_bic pb_bic, pb.acc_number pb_bank_rek, sm.unique_mandate_reference sm_mandaat_ref FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid') sm ON pb_partner_id = p.id

WHERE p.active AND COALESCE(p.deceased,'f') = 'f'
	AND p.membership_end = v.einddatum_vorigjaar
	AND NOT(p.id IN 
			(SELECT p.id FROM myvar v, res_partner p
				JOIN (SELECT MAX(ml.id) max_ml, ml.partner FROM membership_membership_line ml WHERE COALESCE(ml.date_cancel,'1900-01-01')<>'1900-01-01' GROUP BY ml.partner) SQ1 ON SQ1.partner = p.id
				JOIN membership_membership_line ml ON ml.id = SQ1.max_ml
			WHERE COALESCE(ml.date_cancel,p.membership_cancel) BETWEEN v.startdatum_vorigjaar AND v.einddatum
			)
		)
--);
