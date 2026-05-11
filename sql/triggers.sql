
CREATE OR REPLACE TRIGGER TRG_USER_ID
BEFORE INSERT ON User_ FOR EACH ROW
BEGIN
    IF :NEW.User_ID IS NULL THEN 
        :NEW.User_ID := user_seq.NEXTVAL; 
    END IF;
    IF REGEXP_LIKE(:NEW.Name, '^[0-9]+$') THEN
        RAISE_APPLICATION_ERROR(-20010, 'Security Alert: Names cannot be purely numeric.');
    END IF;
    IF :NEW.Date_of_Birth > ADD_MONTHS(SYSDATE, -12 * 18) THEN
        RAISE_APPLICATION_ERROR(-20015, 'Security Alert: User must be at least 18 years old for national registration.');
    END IF;
    IF :NEW.Medical_insurance NOT IN (0, 1) THEN
        RAISE_APPLICATION_ERROR(-20016, 'Validation Error: Insurance must be 0 (No) or 1 (Yes).');
    END IF;
    IF NOT REGEXP_LIKE(:NEW.Blood_Group, '^(A|B|AB|O)[+-]$') THEN
        RAISE_APPLICATION_ERROR(-20017, 'Validation Error: Invalid Blood Group format (Use A+, O-, etc).');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_DONOR_ID
BEFORE INSERT ON Donor FOR EACH ROW
DECLARE
    v_user_exists NUMBER;
BEGIN
    IF :NEW.Donor_ID IS NULL THEN 
        :NEW.Donor_ID := donor_seq.NEXTVAL; 
    END IF;
    SELECT COUNT(*) INTO v_user_exists 
    FROM User_ 
    WHERE User_ID = :NEW.User_ID;
    IF v_user_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'Security Alert: Cannot register donor. Provided User_ID does not exist.');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_PATIENT_ID
BEFORE INSERT ON Patient FOR EACH ROW
DECLARE
    v_user_exists NUMBER;
    v_doctor_exists NUMBER;
BEGIN
    IF :NEW.Patient_ID IS NULL THEN 
        :NEW.Patient_ID := patient_seq.NEXTVAL; 
    END IF;
    SELECT COUNT(*) INTO v_user_exists FROM User_ WHERE User_ID = :NEW.User_ID;
    IF v_user_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20012, 'Security Alert: User ID does not exist in the National Registry.');
    END IF;
    SELECT COUNT(*) INTO v_doctor_exists FROM Doctor WHERE Doctor_ID = :NEW.Doctor_ID;
    IF v_doctor_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20013, 'Security Alert: Doctor ID is not recognized in the system.');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_DOCTOR_ID
BEFORE INSERT ON Doctor FOR EACH ROW
BEGIN
    IF :NEW.Doctor_ID IS NULL THEN :NEW.Doctor_ID := doctor_seq.NEXTVAL; END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_DONATION_ID
BEFORE INSERT ON Donation FOR EACH ROW
DECLARE
    v_donor_exists NUMBER;
BEGIN
    IF :NEW.Donation_ID IS NULL THEN 
        :NEW.Donation_ID := donation_seq.NEXTVAL; 
    END IF;
    SELECT COUNT(*) INTO v_donor_exists FROM Donor WHERE Donor_ID = :NEW.Donor_ID;
    IF v_donor_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20014, 'Security Alert: Donor ID not found. Donation cannot be registered.');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_REQUEST_ID
BEFORE INSERT ON Request FOR EACH ROW
DECLARE
    v_patient_exists NUMBER;
    v_organ_exists NUMBER;
BEGIN
    IF :NEW.Request_ID IS NULL THEN 
        :NEW.Request_ID := request_seq.NEXTVAL; 
    END IF;
    SELECT COUNT(*) INTO v_patient_exists FROM Patient WHERE Patient_ID = :NEW.Patient_ID;
    IF v_patient_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20018, 'Security Alert: Patient ID not found in Registry. Request denied.');
    END IF;
    SELECT COUNT(*) INTO v_organ_exists FROM Organ WHERE Organ_ID = :NEW.Organ_ID;
    IF v_organ_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20019, 'Security Alert: Invalid Organ ID. Specified organ type does not exist.');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_SET_DEFAULTS
BEFORE INSERT ON Donation FOR EACH ROW
BEGIN
    IF :NEW.Status IS NULL THEN :NEW.Status := 'PENDING'; END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_TRANS_DEFAULT
BEFORE INSERT ON Transaction_ FOR EACH ROW
BEGIN
    IF :NEW.Status IS NULL THEN :NEW.Status := 'SUCCESS'; END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_VALIDATE_DONATION
BEFORE INSERT OR UPDATE ON Donation FOR EACH ROW
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM Organ WHERE Organ_ID = :NEW.Organ_ID;
    IF v_count = 0 THEN RAISE_APPLICATION_ERROR(-20001, 'Invalid Organ_ID'); END IF;
    SELECT COUNT(*) INTO v_count FROM Donor WHERE Donor_ID = :NEW.Donor_ID;
    IF v_count = 0 THEN RAISE_APPLICATION_ERROR(-20002, 'Invalid Donor_ID'); END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_LOCK_SUCCESSFUL_DONATION
BEFORE UPDATE ON Donation FOR EACH ROW
BEGIN
    IF :OLD.Status = 'SUCCESSFUL' THEN
        RAISE_APPLICATION_ERROR(-20008, 'Cannot modify a completed transplant record.');
    END IF;
END;
/