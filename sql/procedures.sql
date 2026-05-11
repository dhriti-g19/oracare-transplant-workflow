CREATE SEQUENCE user_seq START WITH 61 INCREMENT BY 1;
CREATE SEQUENCE doctor_seq START WITH 31 INCREMENT BY 1;
CREATE SEQUENCE patient_seq START WITH 31 INCREMENT BY 1;
CREATE SEQUENCE donor_seq START WITH 31 INCREMENT BY 1;
CREATE SEQUENCE donation_seq START WITH 31 INCREMENT BY 1;
CREATE SEQUENCE trans_seq START WITH 31 INCREMENT BY 1;
CREATE SEQUENCE request_seq START WITH 31 INCREMENT BY 1;
CREATE SEQUENCE log_seq START WITH 1 INCREMENT BY 1;

CREATE OR REPLACE PROCEDURE PROC_CREATE_USER(
    p_name              VARCHAR2,
    p_dob               DATE,
    p_gender            VARCHAR2,
    p_blood_group       VARCHAR2,
    p_insurance         NUMBER,
    p_history           VARCHAR2,
    p_street            VARCHAR2,
    p_city              VARCHAR2,
    p_state             VARCHAR2
) AS
BEGIN
    INSERT INTO User_ (
        User_ID, Name, Date_of_Birth, Gender, Blood_Group, 
        Medical_insurance, Medical_history, Street, City, State
    )
    VALUES (
        NULL, p_name, p_dob, p_gender, p_blood_group, 
        p_insurance, p_history, p_street, p_city, p_state
    );
END;
/

CREATE OR REPLACE PROCEDURE PROC_REGISTER_DONOR(
    p_donor_id       NUMBER,
    p_user_id        NUMBER,
    p_org_id         NUMBER,
    p_reason         VARCHAR2
) AS
BEGIN
    INSERT INTO Donor (Donor_ID, User_ID, Organization_ID, Reason_of_donation)
    VALUES (p_donor_id, p_user_id, p_org_id, p_reason);
END;
/

CREATE OR REPLACE PROCEDURE PROC_REGISTER_DOCTOR(
    p_doctor_name    VARCHAR2,
    p_org_id         NUMBER,
    p_specialization VARCHAR2,
    p_password       VARCHAR2 DEFAULT 'doc123'
) AS
BEGIN
    INSERT INTO Doctor (Doctor_ID, Doctor_Name, Organization_ID, Specialization, Password)
    VALUES (NULL, p_doctor_name, p_org_id, p_specialization, p_password);
END;
/

CREATE OR REPLACE PROCEDURE PROC_REGISTER_PATIENT(
    p_user_id        NUMBER,
    p_doctor_id      NUMBER,
    p_reason         VARCHAR2
) AS
BEGIN
    INSERT INTO Patient (Patient_ID, User_ID, Doctor_ID, Reason_of_procurement)
    VALUES (NULL, p_user_id, p_doctor_id, p_reason);
END;
/

CREATE OR REPLACE PROCEDURE PROC_REGISTER_DONATION(
    p_donor_id NUMBER,
    p_organ_id NUMBER
) AS
BEGIN
    INSERT INTO Donation (Donation_ID, Donor_ID, Organ_ID, Donation_date, Status)
    VALUES (NULL, p_donor_id, p_organ_id, SYSDATE, 'PENDING');
END;
/

CREATE OR REPLACE PROCEDURE PROC_CREATE_TRANSACTION(
    p_patient_id NUMBER,
    p_donor_id   NUMBER,
    p_organ_id   NUMBER
) AS
BEGIN
    INSERT INTO Transaction_ (Transaction_ID, Patient_ID, Donor_ID, Organ_ID, Date_of_transaction, Status)
    VALUES (trans_seq.NEXTVAL, p_patient_id, p_donor_id, p_organ_id, SYSDATE, 'SUCCESS');
END;
/

CREATE OR REPLACE PROCEDURE PROC_DELETE_REQUEST(
    p_request_id NUMBER
) AS
BEGIN
    DELETE FROM Request WHERE Request_ID = p_request_id;
END;
/

CREATE OR REPLACE PROCEDURE PROC_LOG_EVENT(
    p_message VARCHAR2
) AS
BEGIN
    INSERT INTO log_ (querytime, comment_)
    VALUES (SYSTIMESTAMP, p_message);
END;
/

CREATE OR REPLACE PROCEDURE GET_ADMIN_REQUESTS(
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT r.Request_ID, 
               u.Name AS Patient_Name, 
               o.Organ_name, 
               r.Request_date, 
               r.Urgency_level
        FROM Request r
        JOIN Patient p ON r.Patient_ID = p.Patient_ID
        JOIN User_ u   ON p.User_ID = u.User_ID
        JOIN Organ o   ON r.Organ_ID = o.Organ_ID
        ORDER BY r.Request_date DESC;
END;
/

CREATE OR REPLACE PROCEDURE GET_ADMIN_DONATIONS(
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT 
            d.Donation_ID, 
            u.Name AS Donor_Name,     
            o.Organ_Name,            
            d.Donation_Date, 
            d.Status             
        FROM Donation d
        JOIN Donor dr ON d.Donor_ID = dr.Donor_ID
        JOIN User_ u  ON dr.User_ID = u.User_ID
        JOIN Organ o  ON d.Organ_ID = o.Organ_ID
        ORDER BY d.Donation_Date DESC;
END;
/

CREATE OR REPLACE PROCEDURE GET_ADMIN_TRANSACTIONS(
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT 
            t.Transaction_ID, 
            t.Patient_ID,     
            t.Donor_ID,
            t.Organ_ID, 
            o.Organ_Name,   
            t.Date_of_transaction, 
            d.Status,        
            r.Request_ID   
        FROM Transaction_ t
        JOIN Organ o ON t.Organ_ID = o.Organ_ID
        JOIN Donation d ON t.Donor_ID = d.Donor_ID AND t.Organ_ID = d.Organ_ID
        LEFT JOIN Request r ON t.Patient_ID = r.Patient_ID AND t.Organ_ID = r.Organ_ID
        ORDER BY t.Date_of_transaction DESC;
END;
/

CREATE OR REPLACE PROCEDURE GET_ORG_REQUESTS (
    p_org_id IN NUMBER,
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT r.Request_ID, r.Patient_ID, r.Organ_ID, r.Urgency_level 
        FROM Request r
        JOIN Patient p ON r.Patient_ID = p.Patient_ID
        JOIN Doctor d  ON p.Doctor_ID = d.Doctor_ID
        WHERE d.Organization_ID = p_org_id
        ORDER BY r.Request_date DESC;
END;
/

CREATE OR REPLACE PROCEDURE PROC_GET_MATCHING_DONORS (
    p_req_id     IN NUMBER,
    p_org_id     IN NUMBER,
    p_patient_id OUT NUMBER,
    p_organ_id   OUT NUMBER,
    p_match_cur  OUT SYS_REFCURSOR
) AS
    v_blood_group VARCHAR2(10);
BEGIN
    BEGIN
        SELECT r.Patient_ID, r.Organ_ID, u.Blood_Group
        INTO p_patient_id, p_organ_id, v_blood_group
        FROM Request r
        JOIN Patient p ON r.Patient_ID = p.Patient_ID
        JOIN Doctor d  ON p.Doctor_ID = d.Doctor_ID
        JOIN User_ u   ON p.User_ID = u.User_ID
        WHERE r.Request_ID = p_req_id AND d.Organization_ID = p_org_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20005, 'Access Denied or Request Not Found');
    END;
    OPEN p_match_cur FOR
        SELECT d.Donor_ID, u.Name
        FROM Donor d
        JOIN User_ u ON d.User_ID = u.User_ID
        JOIN Donation dn ON d.Donor_ID = dn.Donor_ID
        WHERE u.Blood_Group = v_blood_group
        AND dn.Organ_ID = p_organ_id
        AND dn.Status IN ('PENDING', 'In Progress', 'Approved');
END;
/

CREATE OR REPLACE PROCEDURE PROC_AUTHORIZE_TRANSPLANT (
    p_req_id     IN NUMBER,
    p_donor_id   IN NUMBER,
    p_patient_id IN NUMBER,
    p_organ_id   IN NUMBER
) AS
BEGIN
    UPDATE Donation 
    SET Status = 'SUCCESSFUL' 
    WHERE Donor_ID = p_donor_id AND Organ_ID = p_organ_id;
    UPDATE Transaction_ 
    SET Status = 'AUTHORIZED', Date_of_transaction = CURRENT_TIMESTAMP
    WHERE Patient_ID = p_patient_id AND Donor_ID = p_donor_id AND Organ_ID = p_organ_id;
    PROC_DELETE_REQUEST(p_req_id);
    PROC_LOG_EVENT('Transplant Authorized: Request ' || p_req_id || ' for Patient ' || p_patient_id);
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20007, 'Authorization failed at database level.');
END;
/