from datetime import datetime
from flask import Flask, render_template, request, redirect, session, url_for, flash
import os
import oracledb

app = Flask(__name__)
app.secret_key = os.urandom(24)

# database connection
def get_db_connection():
    return oracledb.connect(user="YOUR_USERNAME", password="YOUR_PASSWORD", dsn="localhost:1521/XEPDB1")

# login
@app.route("/")
def home():
    session.clear()
    return render_template("login.html")

@app.route("/login", methods=["POST"])
def login():
    role = request.form["role"]
    username = request.form["username"]
    password = request.form["password"]
    conn = get_db_connection()
    cur = conn.cursor()
    if role == "admin":
        if username == "admin" and password == "admin123":
            session["role"] = "admin"
            session["name"] = "System Administrator"
            return redirect(url_for("admin"))
    elif role == "organization":
        cur.execute("""
            SELECT Organization_ID, Organization_Name FROM Organization WHERE Organization_name = :1 AND password = :2
        """, (username, password))
        org = cur.fetchone()
        if org:
            session["role"] = "organization"
            session["org_id"] = org[0]
            session["name"] = org[1]
            return redirect(url_for("organization"))
    elif role == "doctor":
        cur.execute("""
            SELECT Doctor_ID, Doctor_Name FROM Doctor WHERE Doctor_Name = :1 AND password = :2
        """, (username, password))
        doc = cur.fetchone()
        if doc:
            session["role"] = "doctor"
            session["doctor_id"] = doc[0]
            session["name"] = doc[1]
            return redirect(url_for("doctor"))
    cur.close()
    conn.close()
    return redirect(url_for("home"))

# admin
@app.route("/admin")
def admin():
    if session.get("role") != "admin":
        return redirect(url_for("home"))
    conn = get_db_connection()
    cur = conn.cursor()
    # fetch Totals using your PL/SQL Functions
    cur.execute("SELECT FN_TOTAL_DONORS() FROM dual")
    donors = cur.fetchone()[0]
    cur.execute("SELECT FN_TOTAL_REQUESTS() FROM dual")
    patients = cur.fetchone()[0]
    cur.execute("SELECT FN_TOTAL_ORGANIZATIONS() FROM dual")
    orgs = cur.fetchone()[0]
    cur.execute("SELECT FN_SUCCESSFUL_TRANSACTIONS() FROM dual")
    trans = cur.fetchone()[0]

    # count matches waiting for Government Authorization
    cur.execute("SELECT COUNT(*) FROM Donation WHERE Status = 'AWAITING_AUTH'")
    pending_count = cur.fetchone()[0]

    # aggregation for Chart.js
    cur.execute("""
        SELECT o.Organ_Name, COUNT(d.Donation_ID) FROM Organ o 
        LEFT JOIN Donation d ON o.Organ_ID = d.Organ_ID GROUP BY o.Organ_Name
    """)
    chart_data = cur.fetchall()
    labels = [row[0] for row in chart_data]
    values = [row[1] for row in chart_data]
    cur.close()
    conn.close()
    return render_template("admin_dashboard.html", donors=donors, patients=patients, orgs=orgs, trans=trans, labels=labels, values=values,pending_count=pending_count)

@app.route("/delete_request/<int:req_id>")
def delete_request(req_id):
    if session.get("role") != "admin":
        return redirect(url_for("home"))
    
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.callproc("PROC_DELETE_REQUEST", [req_id])
        conn.commit()
        flash(f"Execution Success: PROC_DELETE_REQUEST completed. Request ID {req_id} removed.", "success")
    except oracledb.DatabaseError as e:
        error_obj, = e.args
        flash(f"Database Error: {error_obj.message}", "error")
        conn.rollback()
    finally:
        cur.close()
        conn.close()
    return redirect(url_for("admin_requests"))

@app.route("/admin_requests")
def admin_requests():
    conn = get_db_connection()
    cur = conn.cursor()
    out_cursor = conn.cursor()
    cur.callproc("GET_ADMIN_REQUESTS", [out_cursor])
    data = out_cursor.fetchall()
    out_cursor.close()
    cur.close()
    conn.close()
    return render_template("admin_requests.html", data=data)

@app.route("/admin_transactions")
def admin_transactions():
    if session.get("role") != "admin":
        return redirect(url_for("home"))
    conn = get_db_connection()
    cur = conn.cursor()
    out_cursor = conn.cursor()
    cur.callproc("GET_ADMIN_TRANSACTIONS", [out_cursor])
    raw_data = out_cursor.fetchall()
    processed_data = []
    for row in raw_data:
        new_row = list(row)
        if new_row[5] and isinstance(new_row[5], str):
            try:
                new_row[5] = datetime.strptime(new_row[5], '%Y-%m-%d %H:%M:%S')
            except ValueError:
                new_row[5] = datetime.strptime(new_row[5], '%Y-%m-%d')
        processed_data.append(tuple(new_row))
    cur.close()
    conn.close()
    return render_template("admin_transactions.html", data=processed_data)

@app.route("/admin_donations")
def admin_donations():
    if session.get("role") != "admin":
        return redirect(url_for("home"))
    conn = get_db_connection()
    cur = conn.cursor()
    out_cursor = conn.cursor()
    cur.callproc("GET_ADMIN_DONATIONS", [out_cursor])
    data = out_cursor.fetchall()
    out_cursor.close()
    cur.close()
    conn.close()
    return render_template("admin_donations.html", data=data)

@app.route("/logs")
def logs():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT TO_CHAR(querytime, 'YYYY-MM-DD HH24:MI:SS'), comment_ FROM log_ ORDER BY querytime DESC")
    data = cur.fetchall()
    cur.close()
    conn.close()
    return render_template("logs.html", data=data)

# organization
@app.route("/organization")
def organization():
    if session.get("role") != "organization":
        return redirect(url_for("home"))
    org_id = session["org_id"]
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM Donor WHERE Organization_ID=:1", (org_id,))
    donors = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM Doctor WHERE Organization_ID=:1", (org_id,))
    doctors = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM Patient")
    patients = cur.fetchone()[0]
    cur.close()
    conn.close()
    return render_template("org_dashboard.html", donors=donors, doctors=doctors, patients=patients)

@app.route("/add_user", methods=["POST"])
def add_user():
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        dob_raw = request.form.get("dob")
        dob_date = datetime.strptime(dob_raw, '%Y-%m-%d')
        params = [request.form.get("name"), dob_date, request.form.get("gender"), request.form.get("blood_group"), int(request.form.get("insurance", 0)), request.form.get("history"), request.form.get("street", ""),  request.form.get("city"), request.form.get("state", "") 
        ]
        cur.callproc("PROC_CREATE_USER", params)
        conn.commit()
        flash("User Profile Created Successfully!", "success") 
    except oracledb.DatabaseError as e:
        error_obj, = e.args
        flash(f"Database Security Alert: {error_obj.message}", "error") 
        conn.rollback()
    except Exception as e:
        flash(f"System Error: {str(e)}", "error")
        conn.rollback()
    finally:
        cur.close()
        conn.close() 
    return redirect(url_for("organization"))

@app.route("/add_donor", methods=["POST"])
def add_donor():
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.callproc("PROC_REGISTER_DONOR", [None, request.form["user_id"], session["org_id"], request.form["reason"]])
        conn.commit()
        flash("Execution Success: PROC_REGISTER_DONOR completed. New Donor ID generated by TRG_DONOR_ID.", "success")
    except oracledb.DatabaseError as e:
        error_obj, = e.args
        flash(f"Database Security Alert: {error_obj.message}", "error")
        conn.rollback()
    finally:
        cur.close()
        conn.close()
    return redirect(url_for("organization"))

@app.route("/add_doctor", methods=["POST"])
def add_doctor():
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.callproc("PROC_REGISTER_DOCTOR", [request.form["doctor_name"], session["org_id"], request.form["specialization"]])
        conn.commit()
        flash("Execution Success: PROC_REGISTER_DOCTOR completed. ID handled by TRG_DOCTOR_ID.", "success")
    except oracledb.DatabaseError as e:
        error_obj, = e.args
        flash(f"Database Security Alert: {error_obj.message}", "error")
        conn.rollback()
    finally:
        cur.close()
        conn.close()
    return redirect(url_for("organization"))

@app.route("/add_patient", methods=["POST"])
def add_patient():
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.callproc("PROC_REGISTER_PATIENT", [request.form["user_id"], request.form["doctor_id"], request.form["procure_reason"]])
        conn.commit()
        flash("Execution Success: PROC_REGISTER_PATIENT completed. ID handled by TRG_PATIENT_ID.", "success")
    except oracledb.DatabaseError as e:
        error_obj, = e.args
        flash(f"Database Security Alert: {error_obj.message}", "error")
        conn.rollback()
    finally:
        cur.close()
        conn.close()
    return redirect(url_for("organization"))

@app.route("/add_donation", methods=["POST"])
def add_donation():
    if session.get("role") != "organization":
        return redirect(url_for("login"))
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        donor_id = int(request.form.get("donor_id"))
        organ_id = int(request.form.get("organ_id"))
        cur.callproc("PROC_REGISTER_DONATION", [donor_id, organ_id])
        conn.commit()
        flash("Execution Success: PROC_REGISTER_DONATION completed. Logic validated by TRG_VALIDATE_DONATION.", "success")
    except oracledb.DatabaseError as e:
        error_obj, = e.args
        flash(f"Database Security Alert: {error_obj.message}", "error")
        conn.rollback()
    except ValueError:
        flash("Invalid input: Please enter numeric IDs.", "error")
    finally:
        cur.close()
        conn.close()
    return redirect(url_for("organization"))

@app.route("/create_request", methods=["POST"])
def create_request():
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO Request (Request_ID, Patient_ID, Organ_ID, Request_date, Urgency_level) 
            VALUES (request_seq.NEXTVAL, :1, :2, SYSDATE, :3)
        """, (request.form["patient_id"], request.form["organ_id"], request.form["urgency"]))
        conn.commit()
        flash("Execution Success: INSERT INTO Request completed. Sequence handled by request_seq.NEXTVAL.", "success")
    except oracledb.DatabaseError as e:
        error_obj, = e.args
        flash(f"Database Security Alert: {error_obj.message}", "error")
        conn.rollback()
    except Exception as e:
        flash(f"System Error: {str(e)}", "error")
        conn.rollback()
    finally:
        cur.close()
        conn.close()
    return redirect(url_for("organization"))

@app.route("/requests")
def requests_page():
    org_id = session.get("org_id")
    if not org_id:
        return redirect(url_for("home"))
    conn = get_db_connection()
    cur = conn.cursor()
    out_cursor = conn.cursor()
    cur.callproc("GET_ORG_REQUESTS", [org_id, out_cursor])
    data = out_cursor.fetchall()
    out_cursor.close()
    cur.close()
    conn.close()
    return render_template("requests.html", data=data)

@app.route("/match/<int:req_id>")
def match(req_id):
    org_id = session.get("org_id")
    if not org_id:
        return redirect(url_for("home"))
    conn = get_db_connection()
    cur = conn.cursor()
    p_patient_id = cur.var(int)
    p_organ_id = cur.var(int)
    p_match_cur = conn.cursor()
    try:
        cur.callproc("PROC_GET_MATCHING_DONORS", [req_id, org_id, p_patient_id, p_organ_id, p_match_cur])
        donors = p_match_cur.fetchall()
        return render_template("match.html", donors=donors, patient_id=p_patient_id.getvalue(), organ_id=p_organ_id.getvalue(), request_id=req_id)
    except oracledb.DatabaseError as e:
        error_obj, = e.args
        if error_obj.code == 20005:
            return "Access Denied: You do not have permission to view this request."
        raise e
    finally:
        p_match_cur.close()
        cur.close()
        conn.close()

@app.route("/confirm_match", methods=["POST"])
def confirm_match():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        UPDATE Donation SET Status = 'AWAITING_AUTH' WHERE Donor_ID = :1 AND Organ_ID = :2
    """, (request.form["donor_id"], request.form["organ_id"]))
    conn.commit()
    cur.close()
    conn.close()
    flash("Match submitted! Awaiting Government Authorization.", "info")
    return redirect(url_for("requests_page"))

@app.route("/authorize_transplant/<int:req_id>/<int:donor_id>/<int:patient_id>/<int:organ_id>")
def authorize_transplant(req_id, donor_id, patient_id, organ_id):
    if session.get("role") != "admin":
        return redirect(url_for("home"))
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.callproc("PROC_AUTHORIZE_TRANSPLANT", [req_id, donor_id, patient_id, organ_id])
        flash("Transplant Authorized Successfully!", "success")
    except Exception as e:
        flash(f"Authorization failed: {str(e)}", "danger")
    finally:
        cur.close()
        conn.close()
    return redirect(url_for("admin_transactions"))

# view transaction
@app.route("/matches")
def view_matches():
    if session.get("role") != "organization":
        return redirect(url_for("home"))
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT t.Transaction_ID, t.Patient_ID, t.Donor_ID, t.Organ_ID, t.Date_of_transaction FROM Transaction_ t
        JOIN Patient p ON t.Patient_ID = p.Patient_ID JOIN Doctor d ON p.Doctor_ID = d.Doctor_ID WHERE d.Organization_ID = :1
    """, (session["org_id"],))
    data = cur.fetchall()
    cur.close()
    conn.close()
    return render_template("admin_transactions.html", data=data) 

# view doctor list
@app.route("/view_doctors")
def view_doctors():
    if session.get("role") != "organization":
        return redirect(url_for("home"))
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT Doctor_ID, Doctor_Name, Specialization FROM Doctor WHERE Organization_ID = :1", (session["org_id"],))
    data = cur.fetchall()
    cur.close()
    conn.close()
    return render_template("view_list.html", title="Affiliated Doctors", data=data)

# view patients list
@app.route("/view_patients")
def view_patients():
    if session.get("role") != "organization":
        return redirect(url_for("home"))
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        SELECT p.Patient_ID, u.Name, p.Reason_of_procurement FROM Patient p 
        JOIN User_ u ON p.User_ID = u.User_ID JOIN Doctor d ON p.Doctor_ID = d.Doctor_ID WHERE d.Organization_ID = :1
    """, (session["org_id"],))
    data = cur.fetchall()
    cur.close()
    conn.close()
    return render_template("view_list.html", title="Managed Patients", data=data)

# doctor
@app.route("/doctor")
def doctor():
    if session.get("role") != "doctor":
        return redirect(url_for("home"))
    doc_id = session["doctor_id"]
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT Doctor_Name FROM Doctor WHERE Doctor_ID = :1", (doc_id,))
    res = cur.fetchone()
    doctor_name = res[0] if res else "Doctor"
    cur.execute("""
        SELECT p.Patient_ID, u.Name, p.Reason_of_procurement,
               CASE WHEN r.Patient_ID IS NOT NULL THEN 'APPROVED' ELSE 'PENDING' END as Status FROM Patient p
        JOIN User_ u ON p.User_ID = u.User_ID LEFT JOIN Request r ON p.Patient_ID = r.Patient_ID WHERE p.Doctor_ID = :1
    """, (doc_id,))
    patients = cur.fetchall()
    cur.execute("""
        SELECT COUNT(*) FROM Patient p WHERE p.Doctor_ID = :1 AND p.Patient_ID NOT IN (SELECT Patient_ID FROM Request)
    """, (doc_id,))
    pending_count = cur.fetchone()[0]
    cur.close()
    conn.close()
    return render_template("doctor_dashboard.html", patients=patients, pending_count=pending_count, doctor_name=doctor_name)

@app.route("/approve_patient", methods=["POST"])
def approve_patient():
    if session.get("role") != "doctor":
        return redirect(url_for("home"))
    patient_id = request.form.get("patient_id")
    organ_id = 1 
    urgency = "High"
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO Request (Request_ID, Patient_ID, Organ_ID, Request_date, Urgency_level) 
            VALUES (request_seq.NEXTVAL, :1, :2, SYSDATE, :3)
        """, (patient_id, organ_id, urgency))
        cur.callproc("PROC_LOG_EVENT", [f"Doctor {session['doctor_id']} approved Patient {patient_id} for transplant."])
        conn.commit()
    except Exception as e:
        print(f"Error during clinical approval: {e}")
        conn.rollback()
    finally:
        cur.close()
        conn.close()
    flash(f"Patient {patient_id} successfully approved and sent to Government queue!", "success")
    return redirect(url_for("doctor"))

@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("home"))

if __name__ == "__main__":
    app.run(debug=True)