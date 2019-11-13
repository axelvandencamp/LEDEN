-----------------------------------------------------------------------
-- LEDEN opgezegd: aangemaakt nav crisis RvB/Ineos
-----------------------------------------------------------------------
SELECT	p.id,
	p.membership_state status,
	p.create_date::date aanmaakdatum,
	--ml.create_date::date start_lidmaatschap,
	p.membership_start Lidmaatschap_startdatum, 
	p.membership_stop Lidmaatschap_einddatum, 
	p.membership_pay_date Betaaldatum, 
	p.membership_end Recentste_einddatum_lidmaatschap, 
	DATE_PART('YEAR',AGE(p.membership_end,p.membership_start)) duurtijd_j,
	p.membership_cancel p_opzegdatum, --opzegdatum 
	ml.date_cancel ml_opzegdatum,
	COALESCE(ml.date_cancel,p.membership_cancel) opzegdatum,
	COALESCE(mcr.name,'onbekend') reden_opzeg,
	p.active,
	CASE
		WHEN p.active THEN COALESCE(pi.name,'geen reden') ELSE ''
	END reden_inactief,
	DATE_PART('YEAR',COALESCE(ml.date_cancel,p.membership_cancel)) opzeg_jaar,
	DATE_PART('MONTH',COALESCE(ml.date_cancel,p.membership_cancel)) opzeg_maand,
	DATE_PART('WEEK',COALESCE(ml.date_cancel,p.membership_cancel)) opzeg_week,
	DATE_PART('DAY',COALESCE(ml.date_cancel,p.membership_cancel)) opzeg_dag
FROM 	res_partner p
	LEFT OUTER JOIN partner_inactive pi ON pi.id = p.inactive_id
	JOIN (SELECT MAX(ml.id) max_ml, ml.partner FROM membership_membership_line ml WHERE COALESCE(ml.date_cancel,'1900-01-01')<>'1900-01-01' GROUP BY ml.partner) SQ1 ON SQ1.partner = p.id
	JOIN membership_membership_line ml ON ml.id = SQ1.max_ml
	LEFT OUTER JOIN membership_cancel_reason mcr ON mcr.id = ml.membership_cancel_id
WHERE	COALESCE(p.membership_cancel,'1900-01-01')<>'1900-01-01'
	OR COALESCE(_crm_opzegdatum_membership(p.id),'1900-01-01')<>'1900-01-01'
