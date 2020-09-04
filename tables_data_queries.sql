
CREATE database WOCO;

CREATE TABLE OWNER (			-- Owner Table
    Id VARCHAR(5) PRIMARY KEY,
    Name VARCHAR(50) NOT NULL
);

CREATE TABLE COMPANY (			-- Company Table inheriting Owner.
    NumOfShares INT CHECK(NumOfShares > 0),  -- A CHECK (NumOfShares > 0) is placed.
    PRIMARY KEY (Id)
) INHERITS (OWNER);


CREATE OR REPLACE FUNCTION company_delete_referential_integrity()
  RETURNS trigger AS
$$
   
BEGIN
	IF OLD.Id IN (SELECT CompanyId FROM COMPANY_SHARES UNION SELECT CompanyId FROM COMPANY_INDUSTRY) THEN
		RAISE EXCEPTION 'A foreign key still pointing to CompanyId!!!';
		RETURN OLD;
	END IF;
 
END;

$$ LANGUAGE plpgsql;

/*COMPANY_ID_COMPANY_CHECK trigger makes sure, rows aren't deleted from COMPANY when other dependent tables have CompanyIds still pointing to them. This situation arose because Foreign Keys couldn't be used in the scenarios.*/

CREATE TRIGGER COMPANY_ID_COMPANY_CHECK
	BEFORE DELETE 
	ON COMPANY
	FOR EACH ROW 
	EXECUTE PROCEDURE company_delete_referential_integrity();

-- As Share Prices of a Company change frequently, we have SharePrice of a Company in COMPANY_SHARES Table.
CREATE TABLE COMPANY_SHARES (
    CompanyId VARCHAR(5) PRIMARY KEY,
    SharePrice REAL NOT NULL CHECK(SharePrice > 0) -- A CHECK (SharePrice > 0) is placed.
);

CREATE OR REPLACE FUNCTION company_referential_integrity()
  RETURNS trigger AS
$$
   
BEGIN
	IF NEW.CompanyId NOT IN (SELECT Id FROM COMPANY) THEN
		RAISE EXCEPTION 'CompanyId Referential Integrity failed!!!';
		IF (TG_OP = 'INSERT') THEN
			RETURN NULL;
		ELSIF (TG_OP = 'UPDATE') THEN
			RETURN OLD;
		END IF;
	END IF;
 
   RETURN NEW;
END;

$$ LANGUAGE plpgsql;

-- Referential Integrity for COMPANY_SHARES (CompanyId) to Company (Id) is enforced using COMPANY_SHARES_CHECK trigger.
CREATE TRIGGER COMPANY_SHARES_CHECK
	BEFORE INSERT OR UPDATE 
	ON COMPANY_SHARES
	FOR EACH ROW 
	EXECUTE PROCEDURE company_referential_integrity();

/*
As industries are usually unique, not assigning Ids to Industries and capturing industry information just as names in COMPANY_INDUSTRY table. We are interested in the Industries only because of their association with the Companies. Thus, not having a seperate table for Industries.
*/

CREATE TABLE COMPANY_INDUSTRY(
    CompanyId VARCHAR(5),
    IndustryNames VARCHAR(50) ARRAY, 
    PRIMARY KEY (CompanyId)
);

/*
Referential Integrity for COMPANY_INDUSTRY (CompanyId) to Company (Id) is enforced using COMPANY_INDUSTRY_CHECK trigger. Not using Foreign key because Companies with BoardMembers are inserted into BOARDMEMBERS.
*/

CREATE TRIGGER COMPANY_INDUSTRY_CHECK
	BEFORE INSERT OR UPDATE 
	ON COMPANY_SHARES
	FOR EACH ROW 
	EXECUTE PROCEDURE company_referential_integrity();
	
/*
If a Company has BoardMembers, the Company information is inserted along with BoardMembers in this table and not inserted in COMPANY. Data Duplication is avoided by using array of BoardMember Identifiers (PersonIds).
*/
CREATE TABLE BOARDMEMBERS (
    PersonIds VARCHAR(5) ARRAY NOT NULL,
    PRIMARY KEY (Id)
) INHERITS (COMPANY);

-- person_id_index placed on PersonIds using GIN Index.
CREATE INDEX person_id_index 
ON BOARDMEMBERS USING GIN(PersonIds);


CREATE OR REPLACE FUNCTION person_referential_integrity()
  RETURNS trigger AS
$$
   
DECLARE
    r VARCHAR(5);
BEGIN
    FOREACH r IN ARRAY NEW.PersonIds
    LOOP
		IF r NOT IN (SELECT Id FROM ONLY Owner) THEN
			RAISE EXCEPTION 'PersonId Referential Integrity failed!!!';
			IF (TG_OP = 'INSERT') THEN
				RETURN NULL;
			ELSIF (TG_OP = 'UPDATE') THEN
				RETURN OLD;
			END IF;
		END IF;
    END LOOP;
 
   RETURN NEW;
END;

$$ LANGUAGE plpgsql;

/*
Referential Integrity for BOARDMEMBERS (PersonIds) to OWNER(Id) is enforced using BOARDMEMBERS_CHECK trigger. Foreign Key not supported for array of entities.
*/
CREATE TRIGGER BOARDMEMBERS_CHECK
	BEFORE INSERT OR UPDATE 
	ON BOARDMEMBERS
	FOR EACH ROW 
	EXECUTE PROCEDURE person_referential_integrity();
	
/*
COMPANY_ID_BOARDMEMBERS_CHECK trigger makes sure, rows aren't deleted from BOARDMEMBERS when other dependent tables have CompanyIds still pointing to them. This situation arose because Foreign Keys couldn't be used in the scenarios.
*/	
CREATE TRIGGER COMPANY_ID_BOARDMEMBERS_CHECK
	BEFORE DELETE 
	ON BOARDMEMBERS
	FOR EACH ROW 
	EXECUTE PROCEDURE company_delete_referential_integrity();

/*
OWNERSHIP table contains the Owner (which can be either a Person or a Company) CompanyWiseShares (shares owned by the owner in all companies) Association.
*/
CREATE TABLE OWNERSHIP (
    OwnerId VARCHAR(5),
    CompanyWiseShares JSON ARRAY NOT NULL, 		-- CompanyWiseShares is an ARRAY of JSON type. JSON of {"CompanyId", "SharesOwned"}.
    PRIMARY KEY (OwnerId)
);

/*
Referential Integrity for OWNERSHIP (OwnerId) to Owner (Id) and OWNERSHIP (CompanyId in CompanyWiseShares) to Company (Id) is enforced using OWNERSHIP_CHECK trigger beacuse Owners actually from both Owners, Company tables and can't use reference key to multiple tables. 

*/
CREATE OR REPLACE FUNCTION ownership_referential_integrity()
  RETURNS trigger AS
$$
   
DECLARE
    r JSON;
BEGIN
	IF NEW.OwnerId NOT IN (SELECT Id FROM Owner) THEN
		RAISE EXCEPTION 'Owner Referential Integrity failed!!!';
		IF (TG_OP = 'INSERT') THEN
			RETURN NULL;
		ELSIF (TG_OP = 'UPDATE') THEN
			RETURN OLD;
		END IF;
	END IF;
	
    FOREACH r IN ARRAY NEW.CompanyWiseShares
    LOOP
    	IF (SELECT value FROM json_each_text(r) WHERE key='CompanyId') NOT IN (SELECT Id FROM COMPANY) THEN
    		RAISE EXCEPTION 'Company Referential Integrity failed!!!';
			RETURN NULL;
		END IF;
    END LOOP;
 
   RETURN NEW;
END;

$$ LANGUAGE plpgsql;
/*
Referential Integrity for OWNERSHIP (OwnerId) to Owner (Id) and OWNERSHIP (CompanyId in CompanyWiseShares) to Company (Id) is enforced using OWNERSHIP_CHECK trigger beacuse Owners actually from both Owners, Company tables and can't use reference key to multiple tables.
*/

CREATE TRIGGER OWNERSHIP_CHECK
	BEFORE INSERT OR UPDATE
	ON OWNERSHIP 
	FOR EACH ROW 
	EXECUTE PROCEDURE ownership_referential_integrity();


------------------------------------ Data -----------------------------------------------------------------------------
INSERT INTO OWNER (Id, Name)
VALUES  ('P1','John Smyth'), ('P2','Bill Doe'), ('P3','Anne Smyle'), ('P4','Bill Seth'), ('P5','Steve Lamp'), ('P6','May Serge'), ('P7','Bill Public'), ('P8','Muck Lain');  

INSERT INTO COMPANY_SHARES (CompanyId, SharePrice)
VALUES ('C1', 30), ('C2', 20), ('C3', 700), ('C4', 400), ('C5', 300), ('C6', 50), ('C7', 300), ('C8', 300), ('C9', 100);  
 
INSERT INTO COMPANY_INDUSTRY (CompanyId, IndustryNames)
VALUES ('C1', ARRAY['Software', 'Accounting']), ('C2', ARRAY['Accounting']), ('C3', ARRAY['Software', 'Automotive']), ('C4', ARRAY['Software', 'Search']), ('C5', ARRAY['Software', 'Hardware']), ('C6', ARRAY['Search']), ('C7', ARRAY['Search']), ('C8', ARRAY['Software', 'Hardware']), ('C9', ARRAY['Software', 'Search']); 

INSERT INTO BOARDMEMBERS(Id, Name, NumOfShares, PersonIds)
VALUES ('C1', 'QUE', 150000, ARRAY['P1', 'P2', 'P3']), ('C2', 'RHC', 250000, ARRAY['P2', 'P4', 'P5']), ('C3', 'Alf', 10000000, ARRAY['P6', 'P7', 'P2']), ('C4', 'Elgog', 1000000, ARRAY['P6', 'P7', 'P5']), ('C5', 'Tfos', 10000000, ARRAY['P3', 'P4', 'P5']), ('C6', 'Ohay', 180000, ARRAY['P4', 'P3', 'P8']), ('C7', 'Gnow', 150000, ARRAY['P4', 'P1', 'P3']), ('C8', 'Elpa', 9000000, ARRAY['P4', 'P1', 'P8']), ('C9', 'Ydex', 5000000, ARRAY['P6', 'P1', 'P8']);

INSERT INTO OWNERSHIP (OwnerId, CompanyWiseShares)
VALUES 
	   ('P2', ARRAY['{"CompanyId": "C5", "SharesOwned": 30000}', '{"CompanyId": "C8", "SharesOwned": 100000}']::json[]),	
	   ('P4', ARRAY['{"CompanyId": "C7", "SharesOwned": 40000}', '{"CompanyId": "C4", "SharesOwned": 20000}']::json[]),
	   ('P1', ARRAY['{"CompanyId": "C1", "SharesOwned": 20000}', '{"CompanyId": "C2", "SharesOwned": 20000}', '{"CompanyId": "C5", "SharesOwned": 800000}']::json[]),	
	   ('P3', ARRAY['{"CompanyId": "C2", "SharesOwned": 30000}', '{"CompanyId": "C5", "SharesOwned": 40000}', '{"CompanyId": "C3", "SharesOwned": 500000}']::json[]),
	   ('P5', ARRAY['{"CompanyId": "C8", "SharesOwned": 90000}', '{"CompanyId": "C1", "SharesOwned": 50000}', '{"CompanyId": "C6", "SharesOwned": 50000}', '{"CompanyId": "C2", "SharesOwned": 70000}']::json[]),
	   ('P6', ARRAY['{"CompanyId": "C8", "SharesOwned": -10000}', '{"CompanyId": "C9", "SharesOwned": -40000}', '{"CompanyId": "C3", "SharesOwned": 500000}', '{"CompanyId": "C2", "SharesOwned": 40000}']::json[]),
	   ('P7', ARRAY['{"CompanyId": "C7", "SharesOwned": 80000}', '{"CompanyId": "C4", "SharesOwned": 30000}', '{"CompanyId": "C1", "SharesOwned": 30000}', '{"CompanyId": "C5", "SharesOwned": 300000}', '{"CompanyId": "C2", "SharesOwned": -9000}']::json[]),
	   ('P8', ARRAY['{"CompanyId": "C2", "SharesOwned": 60000}', '{"CompanyId": "C6", "SharesOwned": -40000}', '{"CompanyId": "C9", "SharesOwned": -80000}', '{"CompanyId": "C8", "SharesOwned": 30000}']::json[]),
	   ('C1', ARRAY['{"CompanyId": "C2", "SharesOwned": 10000}', '{"CompanyId": "C4", "SharesOwned": 20000}', '{"CompanyId": "C8", "SharesOwned": 30000}']::json[]),
	   ('C3', ARRAY['{"CompanyId": "C9", "SharesOwned": -100000}', '{"CompanyId": "C4", "SharesOwned": 400000}', '{"CompanyId": "C8", "SharesOwned": 100000}']::json[]),
	   ('C4', ARRAY['{"CompanyId": "C6", "SharesOwned": 5000}']::json[]),
	   ('C5', ARRAY['{"CompanyId": "C6", "SharesOwned": 30000}', '{"CompanyId": "C7", "SharesOwned": 50000}', '{"CompanyId": "C1", "SharesOwned": 200000}']::json[]),
	   ('C8', ARRAY['{"CompanyId": "C5", "SharesOwned": 20000}', '{"CompanyId": "C4", "SharesOwned": 30000}']::json[]);

----------------------------------------Queries-----------------------------------------------------

-- companies that are (partially) owned by one of their board members
SELECT B.Name as Company
FROM BoardMembers B
WHERE EXISTS(
			 SELECT PersonId -- Checking if a boardmember exists who owns share in the company he/she is boardmember of.
			 FROM unnest(B.PersonIds) PersonId
			 INNER JOIN OWNERSHIP O
			 ON PersonId = O.OwnerId
			 WHERE B.Id IN (
			 				SELECT tmp->>'CompanyId'
			 				FROM unnest(O.CompanyWiseShares) tmp
			 				WHERE (tmp->>'SharesOwned')::int > 0 
			 				AND (tmp->>'SharesOwned')::int != B.NumOfShares
			 			   )
			)
ORDER BY B.Name;

---------------------------------------------------------------------------------
-- net worth for every person in the database
SELECT Name as Person, SUM((TMP.CompanyWiseShares->>'SharesOwned')::int * CS.SharePrice) as NetWorth 
FROM ONLY OWNER O
INNER JOIN (
			SELECT OwnerId, unnest(CompanyWiseShares) as CompanyWiseShares
			FROM OWNERSHIP
		   ) AS TMP
ON O.Id = TMP.OwnerId
INNER JOIN COMPANY_SHARES CS 		-- Getting share price for the company, the person owns shares in.
ON TMP.CompanyWiseShares->>'CompanyId' = CS.CompanyId
WHERE (TMP.CompanyWiseShares->>'SharesOwned')::int > 0 
GROUP BY Name		-- Grouping by Persons
ORDER BY Name;
------------------------------------------------------------------------
-- board member that owns the most shares of that company among all the board members of that company.
SELECT TMP.Name AS Company, O.Name AS TopBoardMember
FROM (
	  SELECT Id AS CompanyId, Name, unnest(PersonIds) AS PersonId
	  FROM BOARDMEMBERS 
	 ) AS TMP
INNER JOIN (	-- Max shares owned by a boardmember in the company.
			SELECT TMP1.CompanyId AS CompanyId, MAX((OP.CompanyWiseShares->>'SharesOwned')::int) as MaxShares 
			FROM (	
				  SELECT Id AS CompanyId, unnest(PersonIds) AS PersonId
	  			  FROM BOARDMEMBERS
				 ) AS TMP1
			INNER JOIN (
			            SELECT OwnerId, unnest(CompanyWiseShares) AS CompanyWiseShares
			            FROM OWNERSHIP
					   ) AS OP
			ON TMP1.PersonId = OP.OwnerId AND TMP1.CompanyId = OP.CompanyWiseShares->>'CompanyId'
			WHERE (OP.CompanyWiseShares->>'SharesOwned')::int > 0
			GROUP BY TMP1.CompanyId 
		   ) AS TMP2
ON TMP.CompanyId = TMP2.CompanyId
INNER JOIN (
			SELECT OwnerId, unnest(CompanyWiseShares) AS CompanyWiseShares
			FROM OWNERSHIP
		   ) AS OP1
ON TMP2.CompanyId = OP1.CompanyWiseShares->>'CompanyId' AND TMP2.MaxShares = (OP1.CompanyWiseShares->>'SharesOwned')::int
AND TMP.PersonId = OP1.OwnerId   -- -- Boardmember who owns Max shares owned by a boardmember in the company.
INNER JOIN OWNER O
ON OP1.OwnerId = O.Id
ORDER BY TMP.Name;


----------------------------------------------------

SELECT c1.Name as Company1, c2.Name as Company2
FROM COMPANY c1, COMPANY c2
WHERE c1.Name != c2.Name 
	  AND
	  EXISTS(
  			SELECT tmp.IndustryName
  			FROM (SELECT unnest(IndustryNames) as IndustryName
  				  FROM COMPANY_INDUSTRY ci1
  			      WHERE ci1.CompanyId = c1.Id) as tmp 
  			WHERE tmp.IndustryName IN  (
										 SELECT unnest(IndustryNames)
										 FROM COMPANY_INDUSTRY ci2
										 WHERE ci2.CompanyId = c2.Id
										)
  			)
	  AND
	  NOT EXISTS(		-- All boardmembers should satisfy the condition thus, EXCEPT leads to 0 entries and nothing exists
	  			SELECT unnest(bm.PersonIds)
	  			FROM boardmembers bm
	  			WHERE bm.Id = c2.Id			-- All boardmembers of Company 2
	  			
	  			EXCEPT
	  			
	  			SELECT bm2.PersonId 				-- boardmembers of Company 2 satisfying the condition in question
	  			FROM (
	  				  SELECT Id, unnest(PersonIds) AS PersonId
	  				  FROM BoardMembers 
	  				 ) AS bm2
	  			WHERE NOT EXISTS(
	  				   			 SELECT TMP1.CompanyWiseShares->>'CompanyId'
	  				   			 FROM (
	  				   			 		SELECT unnest(CompanyWiseShares) AS CompanyWiseShares
										FROM OWNERSHIP
										WHERE OwnerId = bm2.PersonId
	  				   			 	  ) AS TMP1
	  				   			 WHERE (TMP1.CompanyWiseShares->>'SharesOwned')::int > 0	-- All companies, boardmember of company 2 owns shares in.
	  				   			 
	  				   			 EXCEPT
	  				   			 
	  				   			 SELECT pao2.CompanyWiseShares->>'CompanyId'
	  				   			 FROM (
	  				   			 		SELECT unnest(CompanyWiseShares) AS CompanyWiseShares
										FROM OWNERSHIP
										WHERE OwnerId = bm2.PersonId
	  				   			 	  ) AS pao2  -- All companies, boardmember of company 2 owns shares in, that satisfy condition in question.
	  				   			 WHERE (pao2.CompanyWiseShares->>'SharesOwned')::int > 0
	  				   			 	   AND 
	  				   			 	   EXISTS(
	  				   			 			  SELECT * 
	  				   			 			  FROM (
									  				 SELECT Id, unnest(PersonIds) AS PersonId
									  				 FROM BoardMembers 
									  			   ) AS bm1
											  INNER JOIN (
														  SELECT OwnerId, unnest(CompanyWiseShares) as CompanyWiseShares
														  FROM OWNERSHIP
													     ) AS pao1
											  ON bm1.PersonId = pao1.OwnerId
											  WHERE bm1.Id = c1.Id 
											  AND pao1.CompanyWiseShares->>'CompanyId' = pao2.CompanyWiseShares->>'CompanyId' 
											  AND (pao1.CompanyWiseShares->>'SharesOwned')::int >= (pao2.CompanyWiseShares->>'SharesOwned')::int
	  				   			 			 )
	  				  			)
				)
ORDER BY c1.Name, c2.Name;

----------------------------------------------------------------
-- find the companies he controls and the percentage of control, if that percentage is greater than 10%
WITH RECURSIVE ControlPercentage AS (
   (
    SELECT OP.OwnerId, OP.CompanyWiseShares->>'CompanyId' AS CompanyId, -- Direct Ownership
    	   round((OP.CompanyWiseShares->>'SharesOwned')::int * 1.0/c.NumOfShares, 8) AS ShareFraction
    FROM(
   		 SELECT OwnerId, unnest(CompanyWiseShares) AS CompanyWiseShares
   		 FROM OWNERSHIP 
   		) AS OP
    INNER JOIN COMPANY c
    ON OP.CompanyWiseShares->>'CompanyId' = c.Id
    WHERE (OP.CompanyWiseShares->>'SharesOwned')::int > 0
   )
   
   UNION
   
   (SELECT cp1.OwnerId, OP.CompanyWiseShares->>'CompanyId' AS CompanyId, 
           round(((OP.CompanyWiseShares->>'SharesOwned')::int * 1.0/c.NumOfShares)*cp1.ShareFraction, 8) AS ShareFraction
   FROM
   ControlPercentage cp1   -- Direct and Indirect Ownership Until the nth recurrence evaluation step.
   INNER JOIN
   (
	SELECT OwnerId, unnest(CompanyWiseShares) AS CompanyWiseShares
	FROM OWNERSHIP 
   ) AS OP
   ON cp1.CompanyId = OP.OwnerId
   INNER JOIN COMPANY c
   ON OP.CompanyWiseShares->>'CompanyId' = c.Id
   WHERE (OP.CompanyWiseShares->>'SharesOwned')::int > 0) -- Stops ones the stable state is reached.
   ) SELECT o.Name AS Person, c.Name AS Company, round(SUM(cp.ShareFraction*100), 4) AS Percentage
   	 FROM ONLY OWNER o
   	 INNER JOIN ControlPercentage cp
   	 ON o.Id = cp.OwnerId
   	 INNER JOIN COMPANY c
   	 ON cp.CompanyId = c.Id
   	 GROUP BY o.Name, c.Name
   	 HAVING SUM(cp.ShareFraction*100) > 10
   	 ORDER BY o.Name;
			
			
			
			
