declare @country int;
set @country = 50041;

WITH T1 as (SELECT p.policyId,
	   p.sourceKey, 
	   p.policyKey,
	   (CASE p.DataSourceInstanceId WHEN 50044 THEN 'Spain' WHEN 50045 THEN 'Italy' WHEN 50041 THEN 'Portugal' WHEN 50364 THEN 'France_Legacy' WHEN 50498 THEN 'France_TakeOver' ELSE '' END) 'country',
	   cast(p.policyreference as varchar(100)) as policyReference,
	   p.policydescription,
	   cast(p.inceptiondate as date) 'inceptionDate', 
	   cast(p.expirydate as date) 'expiryDate',
	   p.ownershipOrganisation,
	   prod.productId, 
	   prod.productKey,
	   prod.product,
	   prod.productDescription,
	   cast(party.GlobalPartyRole as varchar(250)) as partyRole,
	   party.partyKey,
	   p.ownershipOrganisationKey	
  FROM [rpt].[vwPolicy] p
INNER JOIN rpt.vwPolicySection ps ON p.Policyid = ps.PolicyId
INNER JOIN rpt.vwPOlicySectionProduct psp ON ps.policysectionid = psp.policysectionid
INNER JOIN rpt.vwProduct prod ON psp.productid = prod.ProductId
INNER JOIN rpt.[vwPolicyAttribute] pola ON pola.PolicyId = p.PolicyId
INNER JOIN [rpt].[vwPolicyPartyRole] party ON p.PolicyId=party.PolicyId
WHERE p.DataSourceInstanceId = @country
AND p.ExpiryDate BETWEEN '2020-01-01' AND '2025-12-31'
AND p.isdeleted = 0
AND p.refinsurancetypeid = 100
AND p.refpolicystatusid = 102
and party.GlobalPartyId IS NOT NULL
and party.GlobalPartyRole IN ('Client','Insured')),
T2 as (
SELECT party.partyKey,
	   cast(party.GlobalPartyRole as varchar(250)) as partyType,
	   cast(party_d.Party as varchar(250)) as partyName
 FROM [rpt].[vwPolicyPartyRole] party 
INNER JOIN [rpt].[vwParty] party_d ON party.GlobalPartyId=party_d.SourcePartyId and party.PartyKey=party_d.PartyKey
INNER JOIN (Select GlobalPartyId, MAX(ETLUpdatedDate) as max_date from rpt.[vwPolicyPartyRole] GRoup by GlobalPartyId) p2 ON p2.GlobalPartyId=party.GlobalPartyId and p2.max_date = party.ETLUpdatedDate
WHERE party_d.DataSourceInstanceId=@country
and party.GlobalPartyId IS NOT NULL
and party.GlobalPartyRole IN ('Client','Insured')
GROUP BY party.PartyKey,party.GlobalPartyRole,party_d.Party),
T3 as (SELECT [PartyKey]
      ,(CASE WHEN [SourcePartyId] IS NULL THEN [GlobalPartyId] ELSE [SourcePartyId] END) as GCID
  FROM [rpt].[vwParty] p
  where DataSourceInstanceId=@country
  and IsDeleted=0
  group by p.[PartyKey],[SourcePartyId],[GlobalPartyId]),
T4 as (SELECT pwr.[PolicyId] as pol
      ,pwr.[EmailAddress] as workerEmail
      ,pwr.[Worker] as workerName
  FROM [rpt].[vwPolicyWorkerRole] pwr
  INNER JOIN (Select PolicyId,max(SourceLastUpdateDate) maxxdate FROM [rpt].[vwPolicyWorkerRole] group by PolicyId) AE_MAX on AE_MAX.PolicyId= pwr.PolicyId and  AE_MAX.maxxdate=pwr.SourceLastUpdateDate
  where [DataSourceInstanceId]=50044
  and IsDeleted=0)



SELECT T1.policyId,
	   T1.sourceKey, 
	   T1.policyKey,
	   T1.country,
	   T1.policyReference,
	   T1.policyDescription,
	   T1.inceptionDate, 
	   T1.expiryDate,
	   T1.ownershipOrganisationKey,
	   T1.ownershipOrganisation,
	   T1.productId, 
	   T1.productKey,
	   T1.product,
	   T1.productDescription,
	   T1.partyRole,
	   T1.PartyKey,
	   T2.partyName,
	   T3.gcid,
	   T4.workerEmail,
	   T4.workerName
FROM T1 LEFT JOIN T2 ON T1.PartyKey=T2.PartyKey
		LEFT JOIN T3 ON T1.PartyKey=T3.PartyKey
	    LEFT JOIN T4 ON T1.policyId=T4.pol
Order by T1.policyReference


