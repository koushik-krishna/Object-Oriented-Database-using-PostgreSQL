
DESIGN DECISIONS

We tried to design the schema in such a way that Data Duplication is minimal and all Referential Integrity Constraints are enforced and keep the schema as Object Oriented as possible.


SCHEMA DESCRIPTION AND REFERENTIAL INTEGRITY CONSTRAINTS

OWNER (Id, Name)
1. All persons go directly into OWNER as persons do not have any other attributes other than the ones considered in OWNER i.e., Id and Name.
When we query OWNER using ONLY in query, we get all the PEOPLE Data.

COMPANY INHERITS OWNER (NumOfShares)
1. When we query COMPANY using ONLY in query, we get all the COMPANY Data. 
2. COMPANY INHERITS OWNER.
3. COMPANY inherits OWNER, because when we query OWNER, without using ONLY clause, we would be able to retrieve all entities that can possibly be Owners of shares in some Company.
4. A CHECK (NumOfShares > 0) is placed.
6. COMPANY_ID_COMPANY_CHECK trigger makes sure, rows aren't deleted from COMPANY when other dependent tables have CompanyIds still pointing to them. This situation arose because Foreign Keys couldn't be used in the scenarios.

COMPANY_SHARES (CompanyId, SharePrice)
1. As Share Prices of a Company change frequently, we have SharePrice of a Company in COMPANY_SHARES Table.
2. Referential Integrity for COMPANY_SHARES (CompanyId) to Company (Id) is enforced using COMPANY_SHARES_CHECK trigger.
3. A CHECK (SharePrice > 0) is placed.

COMPANY_INDUSTRY (CompanyId, IndustryNames)
1. As industries are usually unique, not assigning Ids to Industries and capturing industry information just as names in COMPANY_INDUSTRY table.
2. We are interested in the Industries only because of their association with the Companies. Thus, not having a seperate table for Industries.
3. Referential Integrity for COMPANY_INDUSTRY (CompanyId) to Company (Id) is enforced using COMPANY_INDUSTRY_CHECK trigger. Not using Foreign key because Companies with BoardMembers are inserted into BOARDMEMBERS.

BOARDMEMBERS (PersonIds)
1. BOARDMEMBERS INHERITS COMPANY
2. If a Company has BoardMembers, the Company information is inserted along with BoardMembers in this table and not inserted in COMPANY. Data Duplication is avoided by using array of BoardMember Identifiers (PersonIds).
3. Referential Integrity for BOARDMEMBERS (PersonIds) to OWNER(Id) is enforced using BOARDMEMBERS_CHECK trigger. Foreign Key not supported for array of entities.
4. COMPANY_ID_BOARDMEMBERS_CHECK trigger makes sure, rows aren't deleted from BOARDMEMBERS when other dependent tables have CompanyIds still pointing to them. This situation arose because Foreign Keys couldn't be used in the scenarios.
5. person_id_index placed on PersonIds using GIN Index.

OWNERSHIP
1. OWNERSHIP table contains the Owner (which can be either a Person or a Company) CompanyWiseShares (shares owned by the owner in all companies) Association.
2. CompanyWiseShares is an ARRAY of JSON type. JSON of {"CompanyId", "SharesOwned"}.
3. Referential Integrity for OWNERSHIP (OwnerId) to Owner (Id) and OWNERSHIP (CompanyId in CompanyWiseShares) to Company (Id) is enforced using OWNERSHIP_CHECK trigger beacuse Owners actually from both Owners, Company tables and can't use reference key to multiple tables. 

Other indices aren't placed because querying primarily on Primary Keys, which have B-tree index by default.

