-- ============================================================================
-- CONSTRUCTION VMS - Complete Fixed Schema (ALL ERRORS RESOLVED)
-- Features: AI Predictive Maintenance, Complete Maintenance Workflows
-- Inventory Management, Employee Progress Tracking, Transport Services
-- Fuel Monitoring, Hire Vehicle Management, Comprehensive Reporting
-- ============================================================================

/* ============================ 0) EXTENSIONS ================================ */

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

/* ============= 0.1) Utility: updated_at auto-maintainer ==================== */

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

/* ============================= 1) ORGANIZATION ============================= */

CREATE TABLE IF NOT EXISTS company (
                                       company_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                       company_code VARCHAR(50) UNIQUE NOT NULL,
                                       company_name VARCHAR(200) NOT NULL,
                                       company_type VARCHAR(50) CHECK (company_type IN ('construction','logistics','mining','transport','mixed')) DEFAULT 'construction',
                                       registration_no VARCHAR(100) UNIQUE NOT NULL,
                                       tax_id VARCHAR(100),
                                       email VARCHAR(120) NOT NULL,
                                       phone_primary VARCHAR(20) NOT NULL,
                                       address TEXT,
                                       timezone VARCHAR(50) DEFAULT 'Asia/Colombo',
                                       currency VARCHAR(10) DEFAULT 'LKR',
                                       is_active BOOLEAN DEFAULT TRUE,
                                       created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                       updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE TRIGGER trg_company_upd BEFORE UPDATE ON company FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS company_branch (
                                              branch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                              company_id UUID NOT NULL REFERENCES company(company_id) ON DELETE CASCADE,
                                              branch_code VARCHAR(50) UNIQUE NOT NULL,
                                              branch_name VARCHAR(200) NOT NULL,
                                              address TEXT,
                                              city VARCHAR(100),
                                              state_province VARCHAR(100),
                                              country VARCHAR(100),
                                              latitude DECIMAL(10,8),
                                              longitude DECIMAL(11,8),
                                              is_main_workshop BOOLEAN DEFAULT FALSE,
                                              is_active BOOLEAN DEFAULT TRUE,
                                              created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                              updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE TRIGGER trg_branch_upd BEFORE UPDATE ON company_branch FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS department (
                                          department_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                          company_id UUID NOT NULL REFERENCES company(company_id) ON DELETE CASCADE,
                                          branch_id UUID REFERENCES company_branch(branch_id),
                                          department_code VARCHAR(50) UNIQUE NOT NULL,
                                          department_name VARCHAR(120) NOT NULL,
                                          parent_department_id UUID REFERENCES department(department_id),
                                          is_active BOOLEAN DEFAULT TRUE,
                                          created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                          updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE TRIGGER trg_dept_upd BEFORE UPDATE ON department FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS project (
                                       project_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                       company_id UUID NOT NULL REFERENCES company(company_id) ON DELETE CASCADE,
                                       branch_id UUID REFERENCES company_branch(branch_id),
                                       project_code VARCHAR(80) UNIQUE NOT NULL,
                                       project_name VARCHAR(255) NOT NULL,
                                       project_type VARCHAR(50) CHECK (project_type IN ('construction','maintenance','transport','service','mixed')) DEFAULT 'construction',
                                       site_address TEXT,
                                       site_latitude DECIMAL(10,8),
                                       site_longitude DECIMAL(11,8),
                                       start_date DATE NOT NULL,
                                       planned_end_date DATE,
                                       actual_end_date DATE,
                                       budget_amount DECIMAL(15,2),
                                       actual_cost DECIMAL(15,2),
                                       project_manager VARCHAR(100),
                                       status VARCHAR(20) CHECK (status IN ('planning','active','suspended','completed','cancelled')) DEFAULT 'planning',
                                       created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                       updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE TRIGGER trg_project_upd BEFORE UPDATE ON project FOR EACH ROW EXECUTE FUNCTION set_updated_at();

/* ====================== 2) EMPLOYEE & PAYROLL MANAGEMENT =================== */

CREATE TABLE IF NOT EXISTS employee_grade (
                                              grade_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                              grade_code VARCHAR(30) UNIQUE NOT NULL,
                                              grade_name VARCHAR(100) NOT NULL,
                                              category VARCHAR(30) CHECK (category IN ('driver','technician','operator','supervisor','admin','other')) NOT NULL,
                                              base_salary DECIMAL(12,2) NOT NULL,
                                              base_allowance DECIMAL(12,2) DEFAULT 0,
                                              daily_allowance DECIMAL(10,2) DEFAULT 0,
                                              overtime_rate_per_hour DECIMAL(10,2),
                                              notes TEXT,
                                              created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS employee (
                                        employee_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                        company_id UUID NOT NULL REFERENCES company(company_id) ON DELETE CASCADE,
                                        branch_id UUID REFERENCES company_branch(branch_id),
                                        department_id UUID REFERENCES department(department_id),
                                        grade_id UUID REFERENCES employee_grade(grade_id),
                                        employee_code VARCHAR(50) UNIQUE NOT NULL,
                                        first_name VARCHAR(100) NOT NULL,
                                        last_name VARCHAR(100) NOT NULL,
                                        date_of_birth DATE NOT NULL,
                                        gender VARCHAR(20) CHECK (gender IN ('male','female','other')),
                                        national_id VARCHAR(50) UNIQUE NOT NULL,
                                        nic_number VARCHAR(20),
                                        mobile_phone VARCHAR(20) NOT NULL,
                                        work_email VARCHAR(120) UNIQUE,
                                        current_address TEXT,
                                        hire_date DATE NOT NULL,
                                        employment_type VARCHAR(30) CHECK (employment_type IN ('permanent','contract','temporary','intern','consultant')) DEFAULT 'permanent',
                                        job_title VARCHAR(100),
                                        is_driver BOOLEAN DEFAULT FALSE,
                                        is_operator BOOLEAN DEFAULT FALSE,
                                        is_technician BOOLEAN DEFAULT FALSE,
                                        employment_status VARCHAR(20) CHECK (employment_status IN ('active','inactive','suspended','terminated','resigned','retired')) DEFAULT 'active',
                                        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                        updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                        CONSTRAINT chk_employee_age CHECK (EXTRACT(YEAR FROM AGE(date_of_birth)) >= 18)
);
CREATE TRIGGER trg_employee_upd BEFORE UPDATE ON employee FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS employee_skill (
                                              skill_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                              skill_name VARCHAR(100) UNIQUE NOT NULL,
                                              skill_category VARCHAR(50) CHECK (skill_category IN ('technical','operational','safety','administrative')),
                                              description TEXT
);

CREATE TABLE IF NOT EXISTS employee_skill_assessment (
                                                         assessment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                         employee_id UUID NOT NULL REFERENCES employee(employee_id),
                                                         skill_id UUID NOT NULL REFERENCES employee_skill(skill_id),
                                                         assessment_date DATE NOT NULL,
                                                         skill_level VARCHAR(20) CHECK (skill_level IN ('beginner','intermediate','advanced','expert')) NOT NULL,
                                                         assessed_by UUID REFERENCES employee(employee_id),
                                                         notes TEXT,
                                                         created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS employee_training (
                                                 training_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                 training_name VARCHAR(200) NOT NULL,
                                                 training_type VARCHAR(50) CHECK (training_type IN ('safety','technical','operational','soft_skills')),
                                                 description TEXT,
                                                 duration_hours INTEGER,
                                                 provider VARCHAR(100),
                                                 created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS employee_training_record (
                                                        training_record_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                        employee_id UUID NOT NULL REFERENCES employee(employee_id),
                                                        training_id UUID NOT NULL REFERENCES employee_training(training_id),
                                                        training_date DATE NOT NULL,
                                                        completion_date DATE,
                                                        status VARCHAR(20) CHECK (status IN ('scheduled','in_progress','completed','cancelled')) DEFAULT 'scheduled',
                                                        score DECIMAL(5,2),
                                                        certificate_number VARCHAR(100),
                                                        notes TEXT,
                                                        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS employee_complaint (
                                                  complaint_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                  employee_id UUID NOT NULL REFERENCES employee(employee_id),
                                                  complaint_date DATE NOT NULL,
                                                  complaint_type VARCHAR(50) CHECK (complaint_type IN ('work_condition','safety','harassment','equipment','management','other')),
                                                  subject VARCHAR(200) NOT NULL,
                                                  description TEXT NOT NULL,
                                                  priority VARCHAR(20) CHECK (priority IN ('low','medium','high','urgent')) DEFAULT 'medium',
                                                  status VARCHAR(20) CHECK (status IN ('open','investigating','resolved','closed')) DEFAULT 'open',
                                                  assigned_to UUID REFERENCES employee(employee_id),
                                                  resolution TEXT,
                                                  resolved_date DATE,
                                                  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS employee_performance_review (
                                                           review_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                           employee_id UUID NOT NULL REFERENCES employee(employee_id),
                                                           review_date DATE NOT NULL,
                                                           reviewer_id UUID NOT NULL REFERENCES employee(employee_id),
                                                           performance_score DECIMAL(5,2) CHECK (performance_score BETWEEN 0 AND 100),
                                                           attendance_score DECIMAL(5,2),
                                                           productivity_score DECIMAL(5,2),
                                                           safety_score DECIMAL(5,2),
                                                           overall_rating VARCHAR(20) CHECK (overall_rating IN ('excellent','good','satisfactory','needs_improvement')),
                                                           strengths TEXT,
                                                           areas_for_improvement TEXT,
                                                           goals TEXT,
                                                           next_review_date DATE,
                                                           created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

/* ==================== 3) ATTENDANCE / OVERTIME / LEAVE ===================== */

CREATE TABLE IF NOT EXISTS attendance (
                                          attendance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                          employee_id UUID NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
                                          attendance_date DATE NOT NULL,
                                          check_in_time TIMESTAMPTZ,
                                          check_out_time TIMESTAMPTZ,
                                          project_id UUID REFERENCES project(project_id),
                                          latitude_in DECIMAL(10,8),
                                          longitude_in DECIMAL(11,8),
                                          latitude_out DECIMAL(10,8),
                                          longitude_out DECIMAL(11,8),
                                          scheduled_hours DECIMAL(5,2) DEFAULT 8,
                                          actual_hours DECIMAL(5,2),
                                          overtime_hours DECIMAL(5,2) DEFAULT 0,
                                          status VARCHAR(30) CHECK (status IN ('present','absent','late','early_leave','half_day','holiday','weekend','leave')) DEFAULT 'present',
                                          UNIQUE(employee_id, attendance_date)
);
CREATE INDEX IF NOT EXISTS idx_attendance_emp_date ON attendance(employee_id, attendance_date DESC);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance(attendance_date DESC);

CREATE TABLE IF NOT EXISTS overtime_request (
                                                overtime_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                employee_id UUID NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
                                                project_id UUID REFERENCES project(project_id),
                                                ot_date DATE NOT NULL,
                                                hours DECIMAL(5,2) NOT NULL,
                                                ot_type VARCHAR(20) CHECK (ot_type IN ('regular','holiday','weekend','emergency')) DEFAULT 'regular',
                                                approved BOOLEAN DEFAULT FALSE,
                                                approved_by UUID REFERENCES employee(employee_id),
                                                approved_at TIMESTAMPTZ,
                                                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS leave_type (
                                          leave_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                          company_id UUID NOT NULL REFERENCES company(company_id) ON DELETE CASCADE,
                                          leave_code VARCHAR(20) UNIQUE NOT NULL,
                                          leave_name VARCHAR(100) NOT NULL,
                                          days_per_year DECIMAL(5,2) DEFAULT 14
);

CREATE TABLE IF NOT EXISTS leave_application (
                                                 leave_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                 employee_id UUID NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
                                                 leave_type_id UUID NOT NULL REFERENCES leave_type(leave_type_id),
                                                 start_date DATE NOT NULL,
                                                 end_date DATE NOT NULL,
                                                 total_days DECIMAL(5,2) NOT NULL,
                                                 status VARCHAR(20) CHECK (status IN ('pending','approved','rejected','cancelled')) DEFAULT 'pending',
                                                 applied_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                                 approved_by UUID REFERENCES employee(employee_id),
                                                 approved_at TIMESTAMPTZ,
                                                 updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

/* ======================= 3.1) RATIONS / ADVANCES / PAYROLL ================= */

CREATE TABLE IF NOT EXISTS ration_policy (
                                             ration_policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                             company_id UUID NOT NULL REFERENCES company(company_id) ON DELETE CASCADE,
                                             policy_name VARCHAR(100) NOT NULL,
                                             per_day_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
                                             notes TEXT,
                                             is_active BOOLEAN DEFAULT TRUE,
                                             created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ration_distribution (
                                                   ration_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                   employee_id UUID NOT NULL REFERENCES employee(employee_id),
                                                   project_id UUID REFERENCES project(project_id),
                                                   ration_date DATE NOT NULL,
                                                   meals_count INT DEFAULT 1,
                                                   amount DECIMAL(10,2) NOT NULL,
                                                   notes TEXT,
                                                   created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                                   UNIQUE(employee_id, ration_date)
);

CREATE TABLE IF NOT EXISTS employee_advance (
                                                advance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                employee_id UUID NOT NULL REFERENCES employee(employee_id),
                                                issued_date DATE NOT NULL,
                                                amount DECIMAL(12,2) NOT NULL,
                                                balance DECIMAL(12,2) NOT NULL,
                                                purpose TEXT,
                                                status VARCHAR(20) CHECK (status IN ('active','completed')) DEFAULT 'active',
                                                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS payroll (
                                       payroll_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                       employee_id UUID NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
                                       payroll_month INTEGER NOT NULL CHECK (payroll_month BETWEEN 1 AND 12),
                                       payroll_year INTEGER NOT NULL,
                                       basic_salary DECIMAL(12,2) NOT NULL,
                                       overtime_hours DECIMAL(6,2) DEFAULT 0,
                                       overtime_amount DECIMAL(10,2) DEFAULT 0,
                                       ration_total DECIMAL(10,2) DEFAULT 0,
                                       allowances_total DECIMAL(10,2) DEFAULT 0,
                                       advance_deductions DECIMAL(10,2) DEFAULT 0,
                                       other_deductions DECIMAL(10,2) DEFAULT 0,
                                       net_salary DECIMAL(12,2) NOT NULL,
                                       payment_date DATE,
                                       payment_method VARCHAR(30) CHECK (payment_method IN ('bank_transfer','cash','cheque','digital_wallet')),
                                       status VARCHAR(20) CHECK (status IN ('pending','processing','paid','failed')) DEFAULT 'pending',
                                       UNIQUE(employee_id, payroll_month, payroll_year),
                                       created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS payroll_deduction (
                                                 pay_ded_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                 payroll_id UUID NOT NULL REFERENCES payroll(payroll_id) ON DELETE CASCADE,
                                                 deduction_type VARCHAR(40) CHECK (deduction_type IN ('advance_recovery','penalty','other')) NOT NULL,
                                                 reference_id UUID,
                                                 amount DECIMAL(12,2) NOT NULL,
                                                 note TEXT
);

/* ====================== 4) VEHICLE & EQUIPMENT MANAGEMENT ================== */

CREATE TABLE IF NOT EXISTS vehicle_category (
                                                category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                category_name VARCHAR(100) UNIQUE NOT NULL,
                                                category_code VARCHAR(20) UNIQUE NOT NULL,
                                                category_type VARCHAR(50) CHECK (category_type IN ('light_vehicle','heavy_vehicle','excavator','generator','compressor','other_equipment')) NOT NULL,
                                                description TEXT,
                                                icon_url TEXT
);

CREATE TABLE IF NOT EXISTS vehicle_type (
                                            type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                            category_id UUID NOT NULL REFERENCES vehicle_category(category_id),
                                            type_name VARCHAR(100) UNIQUE NOT NULL,
                                            type_code VARCHAR(20) UNIQUE NOT NULL,
                                            fuel_type VARCHAR(30) CHECK (fuel_type IN ('petrol','diesel','electric','hybrid','cng','lpg','hydrogen')) NOT NULL,
                                            service_interval_km INTEGER,
                                            service_interval_months INTEGER,
                                            service_interval_hours INTEGER,
                                            oil_change_interval_km INTEGER,
                                            is_active BOOLEAN DEFAULT TRUE,
                                            created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vehicle_manufacturer (
                                                    manufacturer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                    manufacturer_name VARCHAR(100) UNIQUE NOT NULL,
                                                    country VARCHAR(100),
                                                    website VARCHAR(200),
                                                    support_phone VARCHAR(20),
                                                    support_email VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS vehicle_model (
                                             model_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                             manufacturer_id UUID NOT NULL REFERENCES vehicle_manufacturer(manufacturer_id),
                                             type_id UUID NOT NULL REFERENCES vehicle_type(type_id),
                                             model_name VARCHAR(100) NOT NULL,
                                             model_year INTEGER,
                                             engine_capacity_cc INTEGER,
                                             power_hp INTEGER,
                                             torque_nm INTEGER,
                                             transmission VARCHAR(30) CHECK (transmission IN ('manual','automatic','semi-automatic','cvt')),
                                             drivetrain VARCHAR(20) CHECK (drivetrain IN ('2wd','4wd','awd','fwd','rwd')),
                                             UNIQUE(manufacturer_id, model_name, model_year)
);

CREATE TABLE IF NOT EXISTS vehicle (
                                       vehicle_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                       company_id UUID NOT NULL REFERENCES company(company_id) ON DELETE CASCADE,
                                       branch_id UUID REFERENCES company_branch(branch_id),
                                       model_id UUID NOT NULL REFERENCES vehicle_model(model_id),
                                       vehicle_code VARCHAR(50) UNIQUE NOT NULL,
                                       registration_number VARCHAR(50) UNIQUE NOT NULL,
                                       ownership_type VARCHAR(10) CHECK (ownership_type IN ('own','hire')) NOT NULL,
                                       manufacture_year INTEGER NOT NULL,
                                       color VARCHAR(50),
                                       initial_odometer_km DECIMAL(12,2) DEFAULT 0,
                                       current_odometer_km DECIMAL(12,2) DEFAULT 0,
                                       total_engine_hours DECIMAL(12,2) DEFAULT 0,
                                       consumption_method VARCHAR(20) CHECK (consumption_method IN ('km_per_liter','liter_per_hour')) DEFAULT 'km_per_liter',
                                       rated_efficiency_kmpl DECIMAL(8,3),
                                       rated_consumption_lph DECIMAL(8,3),
                                       operational_status VARCHAR(30) CHECK (operational_status IN ('active','idle','maintenance','breakdown','accident','decommissioned')) DEFAULT 'active',
                                       current_location POINT,
                                       current_project_id UUID REFERENCES project(project_id),
                                       current_driver_id UUID REFERENCES employee(employee_id),
                                       insurance_expiry DATE,
                                       registration_expiry DATE,
                                       notes TEXT,
                                       is_active BOOLEAN DEFAULT TRUE,
                                       decommission_date DATE,
                                       decommission_reason TEXT,
                                       created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                       updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_vehicle_company ON vehicle(company_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_project ON vehicle(current_project_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_status ON vehicle(operational_status);
CREATE INDEX IF NOT EXISTS idx_vehicle_registration ON vehicle(registration_number);
CREATE INDEX IF NOT EXISTS idx_vehicle_ownership ON vehicle(ownership_type);
CREATE INDEX IF NOT EXISTS idx_vehicle_current_status ON vehicle(operational_status, ownership_type) WHERE is_active = true;
CREATE TRIGGER trg_vehicle_upd BEFORE UPDATE ON vehicle FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS vehicle_assignment (
                                                  assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                  vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
                                                  assignment_type VARCHAR(20) CHECK (assignment_type IN ('driver','project')) NOT NULL,
                                                  assigned_to_employee_id UUID REFERENCES employee(employee_id),
                                                  assigned_to_project_id UUID REFERENCES project(project_id),
                                                  assigned_at TIMESTAMPTZ NOT NULL,
                                                  expected_return_at TIMESTAMPTZ,
                                                  returned_at TIMESTAMPTZ,
                                                  start_odometer_km DECIMAL(12,2),
                                                  end_odometer_km DECIMAL(12,2),
                                                  start_fuel_level_percent DECIMAL(5,2),
                                                  end_fuel_level_percent DECIMAL(5,2),
                                                  status VARCHAR(20) CHECK (status IN ('active','completed','cancelled')) DEFAULT 'active',
                                                  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

/* ====================== 5) AI & PREDICTIVE MAINTENANCE ===================== */

CREATE TABLE IF NOT EXISTS ai_model (
                                        model_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                        model_name VARCHAR(200) UNIQUE NOT NULL,
                                        model_type VARCHAR(50) CHECK (model_type IN ('maintenance_prediction','fuel_anomaly','breakdown_prediction','component_life')) NOT NULL,
                                        version VARCHAR(20) NOT NULL,
                                        description TEXT,
                                        accuracy_score DECIMAL(5,4),
                                        training_data_range_start DATE,
                                        training_data_range_end DATE,
                                        features_used JSONB,
                                        hyperparameters JSONB,
                                        is_active BOOLEAN DEFAULT FALSE,
                                        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                        updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- NEW: Machine Learning Training Jobs
CREATE TABLE IF NOT EXISTS ml_training_job (
                                               job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                               model_id UUID REFERENCES ai_model(model_id),
                                               training_started_at TIMESTAMPTZ,
                                               training_completed_at TIMESTAMPTZ,
                                               training_metrics JSONB,
                                               feature_importance JSONB,
                                               training_set_size INTEGER,
                                               validation_score DECIMAL(5,4),
                                               status VARCHAR(20) CHECK (status IN ('running','completed','failed','cancelled')),
                                               created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS maintenance_prediction (
                                                      prediction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                      vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id),
                                                      model_id UUID REFERENCES ai_model(model_id),
                                                      predicted_component VARCHAR(100) NOT NULL,
                                                      prediction_type VARCHAR(50) CHECK (prediction_type IN ('service_due','component_failure','efficiency_drop')) NOT NULL,
                                                      predicted_date DATE NOT NULL,
                                                      confidence_score DECIMAL(5,4) NOT NULL,
                                                      current_risk_level VARCHAR(20) CHECK (current_risk_level IN ('low','medium','high','critical')) DEFAULT 'medium',
                                                      factors_considered JSONB,
                                                      recommended_actions TEXT[],
                                                      is_active BOOLEAN DEFAULT TRUE,
                                                      acknowledged BOOLEAN DEFAULT FALSE,
                                                      acknowledged_by UUID REFERENCES employee(employee_id),
                                                      acknowledged_at TIMESTAMPTZ,
                                                      created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_maintenance_prediction_vehicle ON maintenance_prediction(vehicle_id, predicted_date);
CREATE INDEX IF NOT EXISTS idx_maintenance_prediction_active ON maintenance_prediction(is_active, acknowledged);

-- NEW: Prediction Feedback for Model Improvement
CREATE TABLE IF NOT EXISTS prediction_feedback (
                                                   feedback_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                   prediction_id UUID REFERENCES maintenance_prediction(prediction_id),
                                                   actual_outcome BOOLEAN, -- whether prediction was accurate
                                                   actual_failure_date DATE,
                                                   feedback_notes TEXT,
                                                   reported_by UUID REFERENCES employee(employee_id),
                                                   created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vehicle_health_score (
                                                    health_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                    vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id),
                                                    calculation_date DATE NOT NULL,
                                                    overall_score DECIMAL(5,2) CHECK (overall_score BETWEEN 0 AND 100),
                                                    engine_health DECIMAL(5,2),
                                                    transmission_health DECIMAL(5,2),
                                                    brake_health DECIMAL(5,2),
                                                    tire_health DECIMAL(5,2),
                                                    electrical_health DECIMAL(5,2),
                                                    maintenance_readiness_score DECIMAL(5,2),
                                                    prediction_confidence DECIMAL(5,4),
                                                    factors JSONB,
                                                    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                                    UNIQUE(vehicle_id, calculation_date)
);
CREATE INDEX IF NOT EXISTS idx_vehicle_health_date ON vehicle_health_score(vehicle_id, calculation_date);

CREATE TABLE IF NOT EXISTS component_life_prediction (
                                                         component_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                         vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id),
                                                         component_name VARCHAR(100) NOT NULL,
                                                         component_type VARCHAR(50) CHECK (component_type IN ('engine','transmission','brakes','battery','tires','filters','other')),
                                                         installed_date DATE,
                                                         current_life_percentage DECIMAL(5,2),
                                                         predicted_replacement_date DATE,
                                                         confidence_score DECIMAL(5,4),
                                                         usage_pattern JSONB,
                                                         created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

/* ====================== 6) ENHANCED MAINTENANCE MANAGEMENT ================= */

CREATE TABLE IF NOT EXISTS maintenance_strategy (
                                                    strategy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                    strategy_name VARCHAR(100) NOT NULL,
                                                    strategy_type VARCHAR(30) CHECK (strategy_type IN ('preventive','corrective','predictive','condition_based')) NOT NULL,
                                                    description TEXT
);

CREATE TABLE IF NOT EXISTS maintenance_standard (
                                                    standard_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                    type_id UUID NOT NULL REFERENCES vehicle_type(type_id),
                                                    strategy_id UUID REFERENCES maintenance_strategy(strategy_id),
                                                    standard_code VARCHAR(40) UNIQUE NOT NULL,
                                                    name VARCHAR(120) NOT NULL,
                                                    category VARCHAR(30) CHECK (category IN ('preventive','corrective','predictive','condition_based')) DEFAULT 'preventive',
                                                    interval_km INTEGER,
                                                    interval_months INTEGER,
                                                    interval_engine_hours INTEGER,
                                                    checklist JSONB,
                                                    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS maintenance_program (
                                                   program_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                   program_name VARCHAR(200) NOT NULL,
                                                   program_type VARCHAR(50) CHECK (program_type IN ('preventive','predictive','condition_based')) NOT NULL,
                                                   description TEXT,
                                                   is_active BOOLEAN DEFAULT TRUE,
                                                   created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vehicle_maintenance_program (
                                                           vehicle_program_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                           vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id),
                                                           program_id UUID NOT NULL REFERENCES maintenance_program(program_id),
                                                           start_date DATE NOT NULL,
                                                           end_date DATE,
                                                           is_active BOOLEAN DEFAULT TRUE,
                                                           created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                                           UNIQUE(vehicle_id, program_id)
);

CREATE TABLE IF NOT EXISTS maintenance_plan (
                                                plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id),
                                                plan_name VARCHAR(200) NOT NULL,
                                                plan_type VARCHAR(50) CHECK (plan_type IN ('annual','quarterly','monthly','custom')) NOT NULL,
                                                start_date DATE NOT NULL,
                                                end_date DATE,
                                                total_estimated_cost DECIMAL(12,2),
                                                status VARCHAR(20) CHECK (status IN ('draft','approved','in_progress','completed')) DEFAULT 'draft',
                                                created_by UUID REFERENCES employee(employee_id),
                                                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS maintenance_plan_item (
                                                     plan_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                     plan_id UUID NOT NULL REFERENCES maintenance_plan(plan_id),
                                                     standard_id UUID REFERENCES maintenance_standard(standard_id),
                                                     item_description TEXT NOT NULL,
                                                     scheduled_date DATE NOT NULL,
                                                     estimated_cost DECIMAL(10,2),
                                                     actual_cost DECIMAL(10,2),
                                                     status VARCHAR(20) CHECK (status IN ('scheduled','in_progress','completed','deferred')) DEFAULT 'scheduled',
                                                     completed_date DATE,
                                                     notes TEXT,
                                                     created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS maintenance_schedule (
                                                    schedule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                    vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
                                                    standard_id UUID NOT NULL REFERENCES maintenance_standard(standard_id),
                                                    scheduled_date DATE NOT NULL,
                                                    scheduled_odometer_km DECIMAL(12,2),
                                                    scheduled_engine_hours DECIMAL(12,2),
                                                    ai_predicted_date DATE,
                                                    prediction_confidence DECIMAL(5,2),
                                                    status VARCHAR(20) CHECK (status IN ('scheduled','overdue','in_progress','completed','cancelled','deferred')) DEFAULT 'scheduled',
                                                    notification_sent BOOLEAN DEFAULT FALSE,
                                                    notification_sent_date TIMESTAMPTZ,
                                                    reminder_count INTEGER DEFAULT 0,
                                                    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                                    created_by UUID REFERENCES employee(employee_id),
                                                    UNIQUE (vehicle_id, standard_id, scheduled_date)
);
CREATE INDEX IF NOT EXISTS idx_maintenance_schedule_status ON maintenance_schedule(status) WHERE status <> 'completed';
CREATE INDEX IF NOT EXISTS idx_maintenance_schedule_due ON maintenance_schedule(scheduled_date) WHERE status IN ('scheduled', 'overdue');

CREATE TABLE IF NOT EXISTS breakdown_record (
                                                breakdown_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
                                                driver_id UUID REFERENCES employee(employee_id),
                                                project_id UUID REFERENCES project(project_id),
                                                breakdown_at TIMESTAMPTZ NOT NULL,
                                                location POINT,
                                                odometer_km DECIMAL(12,2),
                                                breakdown_type VARCHAR(50) CHECK (breakdown_type IN ('mechanical','electrical','tire','hydraulic','engine','accident','other')),
                                                severity VARCHAR(20) CHECK (severity IN ('minor','moderate','major','critical')) DEFAULT 'minor',
                                                description TEXT,
                                                repair_category VARCHAR(20) CHECK (repair_category IN ('minor','major')) DEFAULT 'minor',
                                                repair_location VARCHAR(20) CHECK (repair_location IN ('on_site','workshop')) DEFAULT 'workshop',
                                                status VARCHAR(20) CHECK (status IN ('reported','diagnosing','waiting_parts','repairing','completed','closed')) DEFAULT 'reported',
                                                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_breakdown_vehicle_time ON breakdown_record(vehicle_id, breakdown_at DESC);
CREATE INDEX IF NOT EXISTS idx_breakdown_vehicle ON breakdown_record(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_breakdown_status ON breakdown_record(status);
CREATE INDEX IF NOT EXISTS idx_breakdown_date ON breakdown_record(breakdown_at);

CREATE TABLE IF NOT EXISTS repair_job (
                                          repair_job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                          breakdown_id UUID NOT NULL REFERENCES breakdown_record(breakdown_id) ON DELETE CASCADE,
                                          repair_type VARCHAR(20) CHECK (repair_type IN ('in_house','outsourced')) NOT NULL,
                                          diagnosis_notes TEXT,
                                          decided_solution TEXT,
                                          estimated_cost DECIMAL(12,2),
                                          actual_cost DECIMAL(12,2),
                                          start_date DATE,
                                          completion_date DATE,
                                          status VARCHAR(20) CHECK (status IN ('planned','in_progress','waiting_parts','outsourced','completed','closed','cancelled')) DEFAULT 'planned',
                                          created_by UUID REFERENCES employee(employee_id),
                                          created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                          updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE TRIGGER trg_repair_job_upd BEFORE UPDATE ON repair_job FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS maintenance_record (
                                                  maintenance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                  vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
                                                  schedule_id UUID REFERENCES maintenance_schedule(schedule_id),
                                                  breakdown_id UUID REFERENCES breakdown_record(breakdown_id),
                                                  standard_id UUID NOT NULL REFERENCES maintenance_standard(standard_id),
                                                  start_time TIMESTAMPTZ NOT NULL,
                                                  end_time TIMESTAMPTZ,
                                                  odometer_km DECIMAL(12,2) NOT NULL,
                                                  engine_hours DECIMAL(12,2),
                                                  work_performed TEXT NOT NULL,
                                                  parts_used JSONB,
                                                  lubricants_used JSONB,
                                                  labor_cost DECIMAL(10,2),
                                                  parts_cost DECIMAL(10,2),
                                                  lubricants_cost DECIMAL(10,2),
                                                  other_cost DECIMAL(10,2),
                                                  total_cost DECIMAL(12,2),
                                                  next_service_date DATE,
                                                  next_service_odometer_km DECIMAL(12,2),
                                                  status VARCHAR(20) CHECK (status IN ('planned','in_progress','completed','approved','cancelled')) DEFAULT 'in_progress',
                                                  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                                  created_by UUID REFERENCES employee(employee_id),
                                                  approved_by UUID REFERENCES employee(employee_id),
                                                  approved_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_maint_vehicle_time ON maintenance_record(vehicle_id, start_time DESC);
CREATE INDEX IF NOT EXISTS idx_maintenance_vehicle ON maintenance_record(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_date ON maintenance_record(start_time);
CREATE INDEX IF NOT EXISTS idx_vehicle_maintenance_composite ON maintenance_record(vehicle_id, start_time, status);

CREATE TABLE IF NOT EXISTS maintenance_assignment (
                                                      assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                      breakdown_id UUID REFERENCES breakdown_record(breakdown_id) ON DELETE CASCADE,
                                                      maintenance_id UUID REFERENCES maintenance_record(maintenance_id) ON DELETE CASCADE,
                                                      technician_id UUID NOT NULL REFERENCES employee(employee_id),
                                                      assigned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                                      started_at TIMESTAMPTZ,
                                                      completed_at TIMESTAMPTZ,
                                                      status VARCHAR(20) CHECK (status IN ('assigned','in_progress','paused','completed','cancelled')) DEFAULT 'assigned',
                                                      notes TEXT
);

/* ====================== 7) VEHICLE FILTER MANAGEMENT ======================= */

CREATE TABLE IF NOT EXISTS vehicle_filter_type (
                                                   filter_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                   filter_name VARCHAR(100) UNIQUE NOT NULL,
                                                   filter_code VARCHAR(50) UNIQUE NOT NULL,
                                                   description TEXT,
                                                   typical_life_km INTEGER,
                                                   typical_life_hours INTEGER,
                                                   typical_life_months INTEGER
);

CREATE TABLE IF NOT EXISTS vehicle_filter (
                                              filter_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                              vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id),
                                              filter_type_id UUID NOT NULL REFERENCES vehicle_filter_type(filter_type_id),
                                              serial_number VARCHAR(100),
                                              installed_date DATE NOT NULL,
                                              installed_odometer_km DECIMAL(12,2),
                                              installed_engine_hours DECIMAL(12,2),
                                              recommended_replacement_km DECIMAL(12,2),
                                              recommended_replacement_hours DECIMAL(12,2),
                                              actual_replacement_date DATE,
                                              actual_replacement_km DECIMAL(12,2),
                                              actual_replacement_hours DECIMAL(12,2),
                                              replacement_reason VARCHAR(100),
                                              status VARCHAR(20) CHECK (status IN ('active','replaced','expired')) DEFAULT 'active',
                                              created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_vehicle_filter_status ON vehicle_filter(vehicle_id, status);
CREATE INDEX IF NOT EXISTS idx_vehicle_filter_type ON vehicle_filter(filter_type_id);

/* ====================== 8) SUPPLIER & WORKSHOP MANAGEMENT ================== */

CREATE TABLE IF NOT EXISTS supplier (
                                        supplier_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                        supplier_code VARCHAR(50) UNIQUE NOT NULL,
                                        supplier_name VARCHAR(200) NOT NULL,
                                        contact_name VARCHAR(120),
                                        contact_person VARCHAR(100),
                                        phone VARCHAR(20),
                                        email VARCHAR(120),
                                        address TEXT,
                                        tax_id VARCHAR(60),
                                        supplier_type VARCHAR(30) CHECK (supplier_type IN ('parts','service','general')),
                                        is_active BOOLEAN DEFAULT TRUE,
                                        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS petty_cash_voucher (
                                                  voucher_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                  company_id UUID NOT NULL REFERENCES company(company_id) ON DELETE CASCADE,
                                                  project_id UUID REFERENCES project(project_id),
                                                  repair_job_id UUID REFERENCES repair_job(repair_job_id) ON DELETE SET NULL,
                                                  requested_by UUID REFERENCES employee(employee_id),
                                                  approved_by UUID REFERENCES employee(employee_id),
                                                  amount DECIMAL(12,2) NOT NULL,
                                                  purpose TEXT,
                                                  status VARCHAR(20) CHECK (status IN ('requested','approved','rejected','spent','reconciled','cancelled')) DEFAULT 'requested',
                                                  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                                  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE TRIGGER trg_petty_cash_upd BEFORE UPDATE ON petty_cash_voucher FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS workshop_expense (
                                                expense_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                company_id UUID NOT NULL REFERENCES company(company_id) ON DELETE CASCADE,
                                                branch_id UUID REFERENCES company_branch(branch_id),
                                                repair_job_id UUID REFERENCES repair_job(repair_job_id) ON DELETE SET NULL,
                                                maintenance_id UUID REFERENCES maintenance_record(maintenance_id) ON DELETE SET NULL,
                                                vehicle_id UUID REFERENCES vehicle(vehicle_id),
                                                category VARCHAR(30) CHECK (category IN ('parts','labor_external','tools','consumables','services','transport','other')) NOT NULL,
                                                payment_mode VARCHAR(10) CHECK (payment_mode IN ('cash','credit')) NOT NULL,
                                                supplier_id UUID REFERENCES supplier(supplier_id),
                                                description TEXT,
                                                amount DECIMAL(12,2) NOT NULL,
                                                expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
                                                reference_doc_no VARCHAR(100),
                                                created_by UUID REFERENCES employee(employee_id),
                                                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vendor_quotation (
                                                quotation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                supplier_id UUID NOT NULL REFERENCES supplier(supplier_id),
                                                repair_job_id UUID NOT NULL REFERENCES repair_job(repair_job_id) ON DELETE CASCADE,
                                                quote_number VARCHAR(100),
                                                quote_date DATE NOT NULL DEFAULT CURRENT_DATE,
                                                amount DECIMAL(14,2) NOT NULL,
                                                validity_days INTEGER,
                                                notes TEXT,
                                                status VARCHAR(20) CHECK (status IN ('received','accepted','rejected','expired')) DEFAULT 'received',
                                                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS approval_request (
                                                approval_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                entity_type VARCHAR(50) NOT NULL,
                                                entity_id UUID NOT NULL,
                                                requested_by UUID REFERENCES employee(employee_id),
                                                approver_id UUID REFERENCES employee(employee_id),
                                                status VARCHAR(20) CHECK (status IN ('pending','approved','rejected','cancelled')) DEFAULT 'pending',
                                                remarks TEXT,
                                                requested_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                                decided_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS outsourced_repair (
                                                 outsourced_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                 repair_job_id UUID NOT NULL REFERENCES repair_job(repair_job_id) ON DELETE CASCADE,
                                                 supplier_id UUID NOT NULL REFERENCES supplier(supplier_id),
                                                 quotation_id UUID REFERENCES vendor_quotation(quotation_id),
                                                 start_date DATE,
                                                 expected_end_date DATE,
                                                 actual_end_date DATE,
                                                 advance_paid DECIMAL(14,2) DEFAULT 0,
                                                 balance_paid DECIMAL(14,2) DEFAULT 0,
                                                 status VARCHAR(20) CHECK (status IN ('planned','in_progress','completed','closed','cancelled')) DEFAULT 'planned',
                                                 progress_notes TEXT,
                                                 created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

/* ====================== 9) ADVANCED INVENTORY MANAGEMENT =================== */

CREATE TABLE IF NOT EXISTS inventory_category (
                                                  category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                  category_code VARCHAR(30) UNIQUE NOT NULL,
                                                  category_name VARCHAR(120) UNIQUE NOT NULL,
                                                  category_type VARCHAR(30) CHECK (category_type IN ('spare_parts','consumables','lubricants','tools','safety_equipment')) NOT NULL,
                                                  description TEXT,
                                                  is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS inventory_item (
                                              item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                              category_id UUID NOT NULL REFERENCES inventory_category(category_id),
                                              item_code VARCHAR(50) UNIQUE NOT NULL,
                                              item_name VARCHAR(200) NOT NULL,
                                              description TEXT,
                                              manufacturer VARCHAR(200),
                                              model_number VARCHAR(100),
                                              unit_of_measure VARCHAR(20) NOT NULL,
                                              reorder_level DECIMAL(10,2) DEFAULT 0,
                                              current_stock DECIMAL(12,2) DEFAULT 0,
                                              compatible_type_ids UUID[],
                                              average_cost DECIMAL(10,2),
                                              last_purchase_price DECIMAL(10,2),
                                              is_active BOOLEAN DEFAULT TRUE,
                                              created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS inventory_batch (
                                               batch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                               batch_number VARCHAR(100) UNIQUE NOT NULL,
                                               item_id UUID NOT NULL REFERENCES inventory_item(item_id),
                                               manufacturing_date DATE,
                                               expiry_date DATE,
                                               unit_cost DECIMAL(12,2) NOT NULL,
                                               initial_quantity DECIMAL(12,2) NOT NULL,
                                               current_quantity DECIMAL(12,2) NOT NULL,
                                               received_date DATE NOT NULL,
                                               supplier_batch_number VARCHAR(100),
                                               notes TEXT,
                                               created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_inventory_batch_item ON inventory_batch(item_id, expiry_date);

CREATE TABLE IF NOT EXISTS project_inventory (
                                                 project_inventory_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                 project_id UUID NOT NULL REFERENCES project(project_id),
                                                 item_id UUID NOT NULL REFERENCES inventory_item(item_id),
                                                 batch_id UUID REFERENCES inventory_batch(batch_id),
                                                 current_quantity DECIMAL(12,2) NOT NULL DEFAULT 0,
                                                 reserved_quantity DECIMAL(12,2) NOT NULL DEFAULT 0,
                                                 available_quantity DECIMAL(12,2) GENERATED ALWAYS AS (current_quantity - reserved_quantity) STORED,
                                                 last_updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                                 UNIQUE(project_id, item_id, batch_id)
);
CREATE INDEX IF NOT EXISTS idx_project_inventory_item ON project_inventory(project_id, item_id);

CREATE TABLE IF NOT EXISTS inventory_stock (
                                               stock_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                               item_id UUID NOT NULL REFERENCES inventory_item(item_id) ON DELETE CASCADE,
                                               branch_id UUID NOT NULL REFERENCES company_branch(branch_id) ON DELETE CASCADE,
                                               project_id UUID REFERENCES project(project_id),
                                               quantity_on_hand DECIMAL(12,2) NOT NULL,
                                               quantity_reserved DECIMAL(12,2) DEFAULT 0,
                                               quantity_available DECIMAL(12,2) GENERATED ALWAYS AS (quantity_on_hand - quantity_reserved) STORED,
                                               total_value DECIMAL(12,2),
                                               batch_number VARCHAR(100),
                                               expiry_date DATE,
                                               last_updated TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                               UNIQUE(item_id, branch_id, project_id, batch_number)
);

CREATE TABLE IF NOT EXISTS inventory_transaction (
                                                     transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                     item_id UUID NOT NULL REFERENCES inventory_item(item_id),
                                                     batch_id UUID REFERENCES inventory_batch(batch_id),
                                                     branch_id UUID NOT NULL REFERENCES company_branch(branch_id),
                                                     project_id UUID REFERENCES project(project_id),
                                                     transaction_type VARCHAR(30) CHECK (transaction_type IN ('purchase','issue','return','transfer','adjustment','write_off','disposal')),
                                                     transaction_date DATE NOT NULL,
                                                     transaction_time TIMESTAMPTZ NOT NULL,
                                                     quantity DECIMAL(12,2) NOT NULL,
                                                     unit_cost DECIMAL(12,2),
                                                     total_value DECIMAL(14,2),
                                                     total_cost DECIMAL(12,2),
                                                     reference_type VARCHAR(50),
                                                     reference_id UUID,
                                                     vehicle_id UUID REFERENCES vehicle(vehicle_id),
                                                     maintenance_id UUID REFERENCES maintenance_record(maintenance_id),
                                                     supplier_name VARCHAR(200),
                                                     purchase_order_number VARCHAR(100),
                                                     invoice_number VARCHAR(100),
                                                     from_branch_id UUID REFERENCES company_branch(branch_id),
                                                     to_branch_id UUID REFERENCES company_branch(branch_id),
                                                     batch_number VARCHAR(100),
                                                     notes TEXT,
                                                     created_by UUID REFERENCES employee(employee_id),
                                                     created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_inventory_transaction_item ON inventory_transaction(item_id, transaction_date);
CREATE INDEX IF NOT EXISTS idx_inventory_composite ON inventory_transaction(item_id, transaction_date, transaction_type);

CREATE TABLE IF NOT EXISTS inventory_alert (
                                               alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                               item_id UUID NOT NULL REFERENCES inventory_item(item_id),
                                               project_id UUID REFERENCES project(project_id),
                                               alert_type VARCHAR(30) CHECK (alert_type IN ('low_stock','over_stock','expiry','slow_moving')) NOT NULL,
                                               alert_level VARCHAR(20) CHECK (alert_level IN ('info','warning','critical')) DEFAULT 'warning',
                                               current_quantity DECIMAL(12,2),
                                               threshold_quantity DECIMAL(12,2),
                                               message TEXT NOT NULL,
                                               is_resolved BOOLEAN DEFAULT FALSE,
                                               resolved_by UUID REFERENCES employee(employee_id),
                                               resolved_at TIMESTAMPTZ,
                                               created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

/* ====================== 10) PURCHASE & MATERIAL MANAGEMENT ================= */

CREATE TABLE IF NOT EXISTS purchase_request (
                                                pr_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                company_id UUID NOT NULL REFERENCES company(company_id) ON DELETE CASCADE,
                                                project_id UUID REFERENCES project(project_id),
                                                pr_number VARCHAR(100) UNIQUE NOT NULL,
                                                pr_date DATE NOT NULL,
                                                requested_by UUID REFERENCES employee(employee_id),
                                                purpose TEXT,
                                                status VARCHAR(20) CHECK (status IN ('draft','submitted','approved','rejected','converted','cancelled')) DEFAULT 'draft',
                                                notes TEXT,
                                                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS purchase_request_item (
                                                     pr_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                     pr_id UUID NOT NULL REFERENCES purchase_request(pr_id) ON DELETE CASCADE,
                                                     item_id UUID REFERENCES inventory_item(item_id),
                                                     description TEXT,
                                                     quantity DECIMAL(12,2) NOT NULL,
                                                     est_unit_price DECIMAL(12,2),
                                                     project_id UUID REFERENCES project(project_id),
                                                     created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS purchase_order (
                                              po_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                              company_id UUID NOT NULL REFERENCES company(company_id) ON DELETE CASCADE,
                                              project_id UUID REFERENCES project(project_id),
                                              supplier_id UUID NOT NULL REFERENCES supplier(supplier_id),
                                              pr_id UUID REFERENCES purchase_request(pr_id),
                                              po_number VARCHAR(100) UNIQUE NOT NULL,
                                              po_date DATE NOT NULL,
                                              status VARCHAR(20) CHECK (status IN ('draft','approved','partially_received','received','cancelled')) DEFAULT 'draft',
                                              currency VARCHAR(10) DEFAULT 'LKR',
                                              total_amount DECIMAL(14,2),
                                              created_by UUID REFERENCES employee(employee_id),
                                              created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                              approved_by UUID REFERENCES employee(employee_id),
                                              approved_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS purchase_order_item (
                                                   po_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                   po_id UUID NOT NULL REFERENCES purchase_order(po_id) ON DELETE CASCADE,
                                                   item_id UUID REFERENCES inventory_item(item_id),
                                                   description TEXT,
                                                   quantity DECIMAL(12,2) NOT NULL,
                                                   unit_price DECIMAL(12,2) NOT NULL,
                                                   tax_percent DECIMAL(6,2) DEFAULT 0,
                                                   line_total DECIMAL(14,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
                                                   project_id UUID REFERENCES project(project_id),
                                                   created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS goods_receipt_note (
                                                  grn_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                  po_id UUID REFERENCES purchase_order(po_id) ON DELETE SET NULL,
                                                  supplier_id UUID NOT NULL REFERENCES supplier(supplier_id),
                                                  branch_id UUID REFERENCES company_branch(branch_id),
                                                  project_id UUID REFERENCES project(project_id),
                                                  grn_number VARCHAR(100) UNIQUE NOT NULL,
                                                  grn_date DATE NOT NULL,
                                                  received_by UUID REFERENCES employee(employee_id),
                                                  status VARCHAR(20) CHECK (status IN ('draft','posted','cancelled')) DEFAULT 'posted',
                                                  notes TEXT,
                                                  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS goods_receipt_item (
                                                  grn_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                  grn_id UUID NOT NULL REFERENCES goods_receipt_note(grn_id) ON DELETE CASCADE,
                                                  item_id UUID REFERENCES inventory_item(item_id),
                                                  description TEXT,
                                                  quantity DECIMAL(12,2) NOT NULL,
                                                  unit_cost DECIMAL(12,2) NOT NULL,
                                                  line_total DECIMAL(14,2) GENERATED ALWAYS AS (quantity * unit_cost) STORED,
                                                  batch_number VARCHAR(100),
                                                  expiry_date DATE,
                                                  project_id UUID REFERENCES project(project_id),
                                                  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS material_request (
                                                mr_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                requested_by UUID REFERENCES employee(employee_id),
                                                project_id UUID REFERENCES project(project_id),
                                                branch_id UUID REFERENCES company_branch(branch_id),
                                                vehicle_id UUID REFERENCES vehicle(vehicle_id),
                                                mr_number VARCHAR(100) UNIQUE NOT NULL,
                                                mr_date DATE NOT NULL,
                                                status VARCHAR(20) CHECK (status IN ('draft','submitted','approved','rejected','issued','closed')) DEFAULT 'draft',
                                                notes TEXT,
                                                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS material_request_item (
                                                     mr_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                     mr_id UUID NOT NULL REFERENCES material_request(mr_id) ON DELETE CASCADE,
                                                     item_id UUID REFERENCES inventory_item(item_id),
                                                     description TEXT,
                                                     quantity DECIMAL(12,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS material_receipt_note (
                                                     mrn_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                     mr_id UUID REFERENCES material_request(mr_id),
                                                     from_branch_id UUID REFERENCES company_branch(branch_id),
                                                     to_branch_id UUID REFERENCES company_branch(branch_id),
                                                     from_project_id UUID REFERENCES project(project_id),
                                                     to_project_id UUID REFERENCES project(project_id),
                                                     mrn_number VARCHAR(100) UNIQUE NOT NULL,
                                                     mrn_date DATE NOT NULL,
                                                     status VARCHAR(20) CHECK (status IN ('draft','posted','cancelled')) DEFAULT 'posted',
                                                     notes TEXT,
                                                     created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS material_receipt_item (
                                                     mrn_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                     mrn_id UUID NOT NULL REFERENCES material_receipt_note(mrn_id) ON DELETE CASCADE,
                                                     item_id UUID REFERENCES inventory_item(item_id),
                                                     quantity DECIMAL(12,2) NOT NULL,
                                                     batch_number VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS goods_issue_note (
                                                gin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                branch_id UUID REFERENCES company_branch(branch_id),
                                                project_id UUID REFERENCES project(project_id),
                                                maintenance_id UUID REFERENCES maintenance_record(maintenance_id),
                                                gin_number VARCHAR(100) UNIQUE NOT NULL,
                                                gin_date DATE NOT NULL,
                                                issued_by UUID REFERENCES employee(employee_id),
                                                issued_to_type VARCHAR(20) CHECK (issued_to_type IN ('repair','maintenance','project','vehicle','other')) NOT NULL,
                                                issued_to_id UUID,
                                                purpose TEXT,
                                                notes TEXT,
                                                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS goods_issue_item (
                                                gin_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                gin_id UUID NOT NULL REFERENCES goods_issue_note(gin_id) ON DELETE CASCADE,
                                                item_id UUID REFERENCES inventory_item(item_id),
                                                quantity DECIMAL(12,2) NOT NULL,
                                                project_id UUID REFERENCES project(project_id),
                                                unit_cost DECIMAL(12,2),
                                                batch_number VARCHAR(100),
                                                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

/* ====================== 11) TRANSPORTATION SERVICES ======================== */

CREATE TABLE IF NOT EXISTS customer (
                                        customer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                        company_id UUID NOT NULL REFERENCES company(company_id) ON DELETE CASCADE,
                                        customer_code VARCHAR(50) UNIQUE NOT NULL,
                                        customer_name VARCHAR(200) NOT NULL,
                                        customer_type VARCHAR(20) CHECK (customer_type IN ('corporate','government','individual','internal')) DEFAULT 'corporate',
                                        primary_contact_name VARCHAR(100),
                                        primary_contact_phone VARCHAR(20),
                                        primary_contact_email VARCHAR(100),
                                        billing_address TEXT,
                                        shipping_address TEXT,
                                        credit_limit DECIMAL(12,2),
                                        payment_terms_days INTEGER DEFAULT 30,
                                        discount_percentage DECIMAL(5,2) DEFAULT 0,
                                        status VARCHAR(20) CHECK (status IN ('active','inactive','suspended','blacklisted')) DEFAULT 'active',
                                        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                        created_by UUID
);

CREATE TABLE IF NOT EXISTS transport_rate_card (
                                                   rate_card_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                   company_id UUID NOT NULL REFERENCES company(company_id) ON DELETE CASCADE,
                                                   project_id UUID REFERENCES project(project_id),
                                                   vehicle_type_id UUID REFERENCES vehicle_type(type_id),
                                                   rate_name VARCHAR(120) NOT NULL,
                                                   rate_type VARCHAR(30) CHECK (rate_type IN ('hourly','daily','km','trip','fixed','ton_km','cubic_meter','per_km','per_hour','per_trip','per_day')) NOT NULL,
                                                   base_rate DECIMAL(10,2) NOT NULL,
                                                   overtime_rate DECIMAL(10,2),
                                                   holiday_rate DECIMAL(10,2),
                                                   night_shift_rate DECIMAL(10,2),
                                                   minimum_charge DECIMAL(10,2),
                                                   minimum_hours DECIMAL(5,2),
                                                   minimum_distance DECIMAL(10,2),
                                                   effective_from DATE NOT NULL,
                                                   effective_to DATE,
                                                   is_active BOOLEAN DEFAULT TRUE,
                                                   created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vehicle_rate_override (
                                                     override_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                     vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
                                                     rate_card_id UUID NOT NULL REFERENCES transport_rate_card(rate_card_id) ON DELETE CASCADE,
                                                     effective_from DATE NOT NULL,
                                                     effective_to DATE,
                                                     UNIQUE(vehicle_id, rate_card_id, effective_from)
);

CREATE TABLE IF NOT EXISTS transport_work_order (
                                                    work_order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                    company_id UUID NOT NULL REFERENCES company(company_id) ON DELETE CASCADE,
                                                    customer_id UUID REFERENCES customer(customer_id),
                                                    project_id UUID REFERENCES project(project_id),
                                                    order_number VARCHAR(100) UNIQUE NOT NULL,
                                                    order_date DATE NOT NULL,
                                                    order_type VARCHAR(20) CHECK (order_type IN ('rental','transport','project','machine_transport','material_transport','equipment_move')) NOT NULL,
                                                    service_description TEXT NOT NULL,
                                                    vehicle_id UUID REFERENCES vehicle(vehicle_id),
                                                    driver_id UUID REFERENCES employee(employee_id),
                                                    start_time TIMESTAMPTZ NOT NULL,
                                                    end_time TIMESTAMPTZ,
                                                    estimated_hours DECIMAL(8,2),
                                                    actual_hours DECIMAL(8,2),
                                                    pickup_location TEXT,
                                                    pickup_coordinates POINT,
                                                    delivery_location TEXT,
                                                    delivery_coordinates POINT,
                                                    estimated_distance_km DECIMAL(10,2),
                                                    actual_distance_km DECIMAL(10,2),
                                                    rate_card_id UUID REFERENCES transport_rate_card(rate_card_id),
                                                    agreed_rate DECIMAL(10,2),
                                                    estimated_cost DECIMAL(12,2),
                                                    actual_cost DECIMAL(12,2),
                                                    status VARCHAR(20) CHECK (status IN ('draft','confirmed','in_progress','completed','cancelled','invoiced')) DEFAULT 'draft',
                                                    ownership_type_at_service VARCHAR(10) CHECK (ownership_type_at_service IN ('own','hire')),
                                                    notes TEXT,
                                                    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                                    created_by UUID
);
CREATE INDEX IF NOT EXISTS idx_work_order_project ON transport_work_order(project_id, status);

CREATE TABLE IF NOT EXISTS transport_trip (
                                              trip_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                              work_order_id UUID REFERENCES transport_work_order(work_order_id),
                                              vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
                                              driver_id UUID REFERENCES employee(employee_id),
                                              project_id UUID REFERENCES project(project_id),
                                              trip_date DATE NOT NULL,
                                              start_time TIMESTAMPTZ NOT NULL,
                                              end_time TIMESTAMPTZ,
                                              start_odometer_km DECIMAL(12,2),
                                              end_odometer_km DECIMAL(12,2),
                                              actual_distance_km DECIMAL(12,2) GENERATED ALWAYS AS (
                                                  CASE WHEN start_odometer_km IS NOT NULL AND end_odometer_km IS NOT NULL
                                                           THEN GREATEST(end_odometer_km - start_odometer_km, 0) END
                                                  ) STORED,
                                              load_description TEXT,
                                              loading_charges DECIMAL(12,2) DEFAULT 0,
                                              unloading_charges DECIMAL(12,2) DEFAULT 0,
                                              driver_allowance DECIMAL(12,2) DEFAULT 0,
                                              driver_overtime_hours DECIMAL(6,2) DEFAULT 0,
                                              other_trip_cost DECIMAL(12,2) DEFAULT 0,
                                              notes TEXT,
                                              created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_trip_vehicle_time ON transport_trip(vehicle_id, start_time DESC);
CREATE INDEX IF NOT EXISTS idx_trip_vehicle ON transport_trip(vehicle_id, start_time);

/* ====================== 12) VEHICLE RUNNING DETAILS ======================== */

CREATE TABLE IF NOT EXISTS vehicle_daily_activity (
                                                      activity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                      vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
                                                      driver_id UUID REFERENCES employee(employee_id),
                                                      project_id UUID REFERENCES project(project_id),
                                                      activity_date DATE NOT NULL,
                                                      start_time TIMESTAMPTZ,
                                                      end_time TIMESTAMPTZ,
                                                      start_odometer_km DECIMAL(12,2),
                                                      end_odometer_km DECIMAL(12,2),
                                                      engine_hours DECIMAL(10,2),
                                                      distance_km DECIMAL(12,2) GENERATED ALWAYS AS (
                                                          CASE WHEN start_odometer_km IS NOT NULL AND end_odometer_km IS NOT NULL
                                                                   THEN GREATEST(end_odometer_km - start_odometer_km, 0) END
                                                          ) STORED,
                                                      work_description TEXT,
                                                      remarks TEXT,
                                                      created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                                      UNIQUE(vehicle_id, activity_date)
);

CREATE TABLE IF NOT EXISTS vehicle_running_log (
                                                   log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                   vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id),
                                                   driver_id UUID REFERENCES employee(employee_id),
                                                   project_id UUID REFERENCES project(project_id),
                                                   log_date DATE NOT NULL,
                                                   start_time TIMESTAMPTZ,
                                                   end_time TIMESTAMPTZ,
                                                   start_odometer DECIMAL(12,2),
                                                   end_odometer DECIMAL(12,2),
                                                   total_distance DECIMAL(12,2) GENERATED ALWAYS AS (
                                                       CASE WHEN start_odometer IS NOT NULL AND end_odometer IS NOT NULL
                                                                THEN GREATEST(end_odometer - start_odometer, 0) END
                                                       ) STORED,
                                                   engine_hours DECIMAL(10,2),
                                                   fuel_consumed DECIMAL(10,2),
                                                   work_type VARCHAR(50) CHECK (work_type IN ('transport','loading','unloading','idle','maintenance','breakdown')),
                                                   work_description TEXT,
                                                   load_capacity_used DECIMAL(5,2),
                                                   trips_count INTEGER DEFAULT 1,
                                                   operator_signature TEXT,
                                                   supervisor_approval UUID REFERENCES employee(employee_id),
                                                   created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_vehicle_running_date ON vehicle_running_log(vehicle_id, log_date);

CREATE TABLE IF NOT EXISTS vehicle_operating_cost (
                                                      cost_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                      vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id),
                                                      cost_date DATE NOT NULL,
                                                      cost_type VARCHAR(50) CHECK (cost_type IN ('fuel','maintenance','repair','tires','battery','insurance','tax','other')),
                                                      description TEXT,
                                                      amount DECIMAL(12,2) NOT NULL,
                                                      odometer_km DECIMAL(12,2),
                                                      reference_type VARCHAR(50),
                                                      reference_id UUID,
                                                      created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_vehicle_operating_cost ON vehicle_operating_cost(vehicle_id, cost_date);

/* ====================== 13) FUEL & AI MONITORING =========================== */

CREATE TABLE IF NOT EXISTS fuel_station (
                                            station_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                            station_name VARCHAR(200) NOT NULL,
                                            station_code VARCHAR(50) UNIQUE NOT NULL,
                                            address TEXT,
                                            location POINT,
                                            contact_person VARCHAR(100),
                                            phone VARCHAR(20),
                                            email VARCHAR(100),
                                            payment_method VARCHAR(30) CHECK (payment_method IN ('cash','credit','fuel_card','account')),
                                            credit_limit DECIMAL(12,2),
                                            credit_days INTEGER,
                                            current_diesel_price DECIMAL(8,2),
                                            current_petrol_price DECIMAL(8,2),
                                            is_preferred BOOLEAN DEFAULT FALSE,
                                            is_active BOOLEAN DEFAULT TRUE,
                                            created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS fuel_transaction (
                                                transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
                                                driver_id UUID NOT NULL REFERENCES employee(employee_id),
                                                station_id UUID REFERENCES fuel_station(station_id),
                                                project_id UUID REFERENCES project(project_id),
                                                transaction_time TIMESTAMPTZ NOT NULL,
                                                transaction_date DATE NOT NULL,
                                                odometer_km DECIMAL(12,2) NOT NULL,
                                                engine_hours DECIMAL(12,2),
                                                fuel_type VARCHAR(30) NOT NULL,
                                                quantity_liters DECIMAL(10,2) NOT NULL,
                                                price_per_liter DECIMAL(8,2) NOT NULL,
                                                total_amount DECIMAL(12,2) NOT NULL,
                                                previous_odometer_km DECIMAL(12,2),
                                                distance_since_last_fill DECIMAL(10,2),
                                                fuel_efficiency DECIMAL(8,3),
                                                tank_full BOOLEAN DEFAULT FALSE,
                                                payment_method VARCHAR(30),
                                                receipt_number VARCHAR(100),
                                                receipt_photo_url TEXT,
                                                fuel_card_number VARCHAR(50),
                                                approved_by UUID REFERENCES employee(employee_id),
                                                approval_status VARCHAR(20) CHECK (approval_status IN ('pending','approved','rejected')) DEFAULT 'pending',
                                                approval_notes TEXT,
                                                consumption_analysis JSONB,
                                                anomaly_detected BOOLEAN DEFAULT FALSE,
                                                anomaly_type VARCHAR(50),
                                                expected_consumption_l DECIMAL(10,2),
                                                variance_percent DECIMAL(8,2),
                                                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_fuel_vehicle ON fuel_transaction(vehicle_id, transaction_time DESC);
CREATE INDEX IF NOT EXISTS idx_fuel_driver ON fuel_transaction(driver_id);
CREATE INDEX IF NOT EXISTS idx_fuel_anomaly ON fuel_transaction(anomaly_detected) WHERE anomaly_detected = TRUE;
CREATE INDEX IF NOT EXISTS idx_fuel_vehicle_date ON fuel_transaction(vehicle_id, transaction_date);
CREATE INDEX IF NOT EXISTS idx_fuel_composite ON fuel_transaction(vehicle_id, transaction_date, anomaly_detected);

CREATE TABLE IF NOT EXISTS abnormal_fuel_adjustment (
                                                        adjust_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                        vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
                                                        period_year INT NOT NULL,
                                                        period_month INT NOT NULL CHECK (period_month BETWEEN 1 AND 12),
                                                        source VARCHAR(10) CHECK (source IN ('own','hire')) NOT NULL,
                                                        abnormal_liters DECIMAL(12,2) NOT NULL,
                                                        reason TEXT,
                                                        approved_by UUID REFERENCES employee(employee_id),
                                                        approved_at TIMESTAMPTZ,
                                                        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                                        UNIQUE(vehicle_id, period_year, period_month, source)
);

/* ====================== 14) HIRE VEHICLE MANAGEMENT ======================== */

CREATE TABLE IF NOT EXISTS hire_contract (
                                             hire_contract_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                             vehicle_id UUID UNIQUE NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
                                             supplier_id UUID NOT NULL REFERENCES supplier(supplier_id),
                                             start_date DATE NOT NULL,
                                             end_date DATE,
                                             rate_type VARCHAR(30) CHECK (rate_type IN ('hourly','daily','km','trip','fixed','per_km','per_hour','per_day','per_month')) NOT NULL,
                                             rate_amount DECIMAL(12,2) NOT NULL,
                                             included_km DECIMAL(10,2),
                                             included_hours DECIMAL(10,2),
                                             overtime_rate DECIMAL(12,2),
                                             hire_basis VARCHAR(10) CHECK (hire_basis IN ('wet','dry')) NOT NULL DEFAULT 'dry',
                                             billing_cycle VARCHAR(10) CHECK (billing_cycle IN ('monthly')) NOT NULL DEFAULT 'monthly',
                                             billing_day_of_month SMALLINT CHECK (billing_day_of_month BETWEEN 1 AND 31) DEFAULT 1,
                                             wet_deduct_all_fuel BOOLEAN DEFAULT TRUE,
                                             dry_allow_abnormal_deduct BOOLEAN DEFAULT TRUE,
                                             abnormal_threshold_pct DECIMAL(6,2) DEFAULT 20.00,
                                             contract_eff_kmpl DECIMAL(8,3),
                                             contract_lph DECIMAL(8,3),
                                             fuel_price_source VARCHAR(10) CHECK (fuel_price_source IN ('actual','avg')) DEFAULT 'actual',
                                             notes TEXT,
                                             created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                             updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE TRIGGER trg_hire_contract_upd BEFORE UPDATE ON hire_contract FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS hire_usage_monthly (
                                                  usage_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                  vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
                                                  hire_contract_id UUID NOT NULL REFERENCES hire_contract(hire_contract_id) ON DELETE CASCADE,
                                                  usage_year INT NOT NULL,
                                                  usage_month INT NOT NULL CHECK (usage_month BETWEEN 1 AND 12),
                                                  total_km DECIMAL(12,2),
                                                  total_hours DECIMAL(12,2),
                                                  actual_fuel_l DECIMAL(12,2),
                                                  fuel_amount DECIMAL(14,2),
                                                  expected_fuel_l DECIMAL(12,2),
                                                  variance_l DECIMAL(12,2),
                                                  variance_pct DECIMAL(6,2),
                                                  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                                  UNIQUE (vehicle_id, usage_year, usage_month)
);

CREATE TABLE IF NOT EXISTS hire_bill (
                                         hire_bill_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                         hire_contract_id UUID NOT NULL REFERENCES hire_contract(hire_contract_id) ON DELETE CASCADE,
                                         supplier_id UUID NOT NULL REFERENCES supplier(supplier_id),
                                         vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id),
                                         bill_year INT NOT NULL,
                                         bill_month INT NOT NULL CHECK (bill_month BETWEEN 1 AND 12),
                                         hire_basis VARCHAR(10) CHECK (hire_basis IN ('wet','dry')) NOT NULL,
                                         total_km DECIMAL(12,2),
                                         total_hours DECIMAL(12,2),
                                         actual_fuel_l DECIMAL(12,2),
                                         fuel_amount DECIMAL(14,2),
                                         expected_fuel_l DECIMAL(12,2),
                                         abnormal_fuel_l DECIMAL(12,2),
                                         base_charge DECIMAL(14,2) DEFAULT 0,
                                         extra_charge DECIMAL(14,2) DEFAULT 0,
                                         fuel_deduction DECIMAL(14,2) DEFAULT 0,
                                         abnormal_deduction DECIMAL(14,2) DEFAULT 0,
                                         other_deductions DECIMAL(14,2) DEFAULT 0,
                                         gross_amount DECIMAL(14,2) DEFAULT 0,
                                         total_deductions DECIMAL(14,2) DEFAULT 0,
                                         net_payable DECIMAL(14,2) DEFAULT 0,
                                         status VARCHAR(20) CHECK (status IN ('draft','review','approved','posted','paid','cancelled')) DEFAULT 'draft',
                                         created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                         created_by UUID REFERENCES employee(employee_id),
                                         approved_by UUID REFERENCES employee(employee_id),
                                         approved_at TIMESTAMPTZ,
                                         UNIQUE (hire_contract_id, bill_year, bill_month)
);
CREATE INDEX IF NOT EXISTS idx_hire_bill_period ON hire_bill(bill_year, bill_month, status);

CREATE TABLE IF NOT EXISTS hire_bill_component (
                                                   component_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                   hire_bill_id UUID NOT NULL REFERENCES hire_bill(hire_bill_id) ON DELETE CASCADE,
                                                   component_type VARCHAR(30) CHECK (component_type IN ('base','extra_km','extra_hours','overtime','standby','trip','fixed')) NOT NULL,
                                                   quantity DECIMAL(12,2) NOT NULL,
                                                   rate DECIMAL(12,2) NOT NULL,
                                                   amount DECIMAL(14,2) GENERATED ALWAYS AS (quantity * rate) STORED,
                                                   note TEXT
);

CREATE TABLE IF NOT EXISTS hire_deduction_type (
                                                   deduction_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                   code VARCHAR(50) UNIQUE NOT NULL,
                                                   label VARCHAR(120) NOT NULL
);

CREATE TABLE IF NOT EXISTS hire_bill_deduction (
                                                   deduction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                   hire_bill_id UUID NOT NULL REFERENCES hire_bill(hire_bill_id) ON DELETE CASCADE,
                                                   deduction_type_id UUID NOT NULL REFERENCES hire_deduction_type(deduction_type_id),
                                                   basis VARCHAR(10) CHECK (basis IN ('liters','amount')) NOT NULL DEFAULT 'amount',
                                                   liters DECIMAL(12,2),
                                                   rate_per_liter DECIMAL(12,2),
                                                   amount DECIMAL(14,2) GENERATED ALWAYS AS (
                                                       CASE WHEN basis='liters' THEN COALESCE(liters,0)*COALESCE(rate_per_liter,0)
                                                            ELSE COALESCE(rate_per_liter,0) END
                                                       ) STORED,
                                                   note TEXT
);

/* ====================== 15) TYRE MANAGEMENT ================================ */

CREATE TABLE IF NOT EXISTS tyre (
                                    tyre_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                    item_id UUID REFERENCES inventory_item(item_id),
                                    serial_number VARCHAR(100) UNIQUE NOT NULL,
                                    brand VARCHAR(100),
                                    model VARCHAR(100),
                                    size_spec VARCHAR(60),
                                    ply_rating VARCHAR(20),
                                    speed_rating VARCHAR(10),
                                    load_index VARCHAR(10),
                                    manufacture_date DATE,
                                    purchase_date DATE,
                                    purchase_invoice VARCHAR(100),
                                    original_tread_mm NUMERIC(5,2),
                                    is_retread BOOLEAN DEFAULT FALSE,
                                    notes TEXT,
                                    status VARCHAR(20) CHECK (status IN ('in_stock','fitted','repair','retired','scrapped')) DEFAULT 'in_stock',
                                    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE TRIGGER trg_tyre_upd BEFORE UPDATE ON tyre FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS vehicle_tyre_fitment (
                                                    fitment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                    vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
                                                    tyre_id UUID NOT NULL REFERENCES tyre(tyre_id) ON DELETE RESTRICT,
                                                    axle_number SMALLINT NOT NULL CHECK (axle_number >= 1),
                                                    wheel_position VARCHAR(1) NOT NULL CHECK (wheel_position IN ('L','R','C')),
                                                    position_note VARCHAR(60),
                                                    fitted_at TIMESTAMPTZ NOT NULL,
                                                    removed_at TIMESTAMPTZ,
                                                    fitted_odometer_km NUMERIC(12,2),
                                                    removed_odometer_km NUMERIC(12,2),
                                                    fitted_by UUID REFERENCES employee(employee_id),
                                                    removed_by UUID REFERENCES employee(employee_id),
                                                    reason_removed VARCHAR(40) CHECK (reason_removed IN ('rotation','worn','repair','damage','seasonal','other')),
                                                    is_active BOOLEAN GENERATED ALWAYS AS (removed_at IS NULL) STORED,
                                                    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_vtf_vehicle_active ON vehicle_tyre_fitment(vehicle_id) WHERE removed_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_vehicle_tyre_slot_active
    ON vehicle_tyre_fitment(vehicle_id, axle_number, wheel_position) WHERE removed_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_tyre_active_fitment
    ON vehicle_tyre_fitment(tyre_id) WHERE removed_at IS NULL;

CREATE TABLE IF NOT EXISTS tyre_inspection (
                                               inspection_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                               tyre_id UUID NOT NULL REFERENCES tyre(tyre_id) ON DELETE CASCADE,
                                               vehicle_id UUID REFERENCES vehicle(vehicle_id) ON DELETE SET NULL,
                                               inspection_time TIMESTAMPTZ NOT NULL,
                                               odometer_km NUMERIC(12,2),
                                               tread_depth_mm NUMERIC(5,2),
                                               pressure_psi NUMERIC(6,2),
                                               wear_pattern VARCHAR(30) CHECK (wear_pattern IN ('normal','center','shoulder','feathering','cupping','flat_spot','uneven','other')) DEFAULT 'normal',
                                               damage_notes TEXT,
                                               action_taken VARCHAR(40) CHECK (action_taken IN ('none','inflate','deflate','rotate','repair','replace')) DEFAULT 'none',
                                               inspected_by UUID REFERENCES employee(employee_id),
                                               created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_tyre_insp_tyre_time ON tyre_inspection(tyre_id, inspection_time DESC);

CREATE TABLE IF NOT EXISTS tyre_repair (
                                           repair_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                           tyre_id UUID NOT NULL REFERENCES tyre(tyre_id) ON DELETE CASCADE,
                                           vehicle_id UUID REFERENCES vehicle(vehicle_id),
                                           reported_time TIMESTAMPTZ NOT NULL,
                                           repair_time TIMESTAMPTZ,
                                           odometer_km NUMERIC(12,2),
                                           repair_type VARCHAR(30) CHECK (repair_type IN ('puncture','sidewall','bead','valve','patch','replace','other')) NOT NULL,
                                           vendor_name VARCHAR(120),
                                           cost_amount NUMERIC(12,2),
                                           maintenance_id UUID REFERENCES maintenance_record(maintenance_id),
                                           notes TEXT,
                                           created_by UUID REFERENCES employee(employee_id),
                                           created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_tyre_repair_tyre_time ON tyre_repair(tyre_id, reported_time DESC);

CREATE TABLE IF NOT EXISTS tyre_rotation (
                                             rotation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                             vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
                                             rotation_time TIMESTAMPTZ NOT NULL,
                                             odometer_km NUMERIC(12,2),
                                             scheme VARCHAR(30) CHECK (scheme IN ('front_rear','cross','five_wheel','custom')) DEFAULT 'custom',
                                             notes TEXT,
                                             performed_by UUID REFERENCES employee(employee_id),
                                             created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tyre_rotation_detail (
                                                    rotation_detail_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                    rotation_id UUID NOT NULL REFERENCES tyre_rotation(rotation_id) ON DELETE CASCADE,
                                                    tyre_id UUID NOT NULL REFERENCES tyre(tyre_id),
                                                    from_axle SMALLINT,
                                                    from_pos VARCHAR(1) CHECK (from_pos IN ('L','R','C')),
                                                    to_axle SMALLINT,
                                                    to_pos VARCHAR(1) CHECK (to_pos IN ('L','R','C'))
);
CREATE INDEX IF NOT EXISTS idx_tyre_rotation_detail_tyre ON tyre_rotation_detail(tyre_id);

/* ====================== 16) BATTERY MANAGEMENT ============================= */

CREATE TABLE IF NOT EXISTS battery (
                                       battery_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                       item_id UUID REFERENCES inventory_item(item_id),
                                       serial_number VARCHAR(100) UNIQUE NOT NULL,
                                       brand VARCHAR(100),
                                       model VARCHAR(100),
                                       capacity_ah NUMERIC(6,2),
                                       voltage_v NUMERIC(5,2) DEFAULT 12.00,
                                       manufacture_date DATE,
                                       purchase_date DATE,
                                       purchase_invoice VARCHAR(100),
                                       warranty_months INTEGER CHECK (warranty_months BETWEEN 0 AND 72) DEFAULT 12,
                                       pro_rata_months INTEGER CHECK (pro_rata_months BETWEEN 0 AND 72),
                                       warranty_terms TEXT,
                                       warranty_expiry_date DATE,
                                       notes TEXT,
                                       status VARCHAR(20) CHECK (status IN ('in_stock','installed','claim','retired','scrapped')) DEFAULT 'in_stock',
                                       created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                       updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE TRIGGER trg_battery_upd BEFORE UPDATE ON battery FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS vehicle_battery_installation (
                                                            install_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                            vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
                                                            battery_id UUID NOT NULL REFERENCES battery(battery_id) ON DELETE RESTRICT,
                                                            installed_at TIMESTAMPTZ NOT NULL,
                                                            removed_at TIMESTAMPTZ,
                                                            installed_odometer_km NUMERIC(12,2),
                                                            removed_odometer_km NUMERIC(12,2),
                                                            installed_by UUID REFERENCES employee(employee_id),
                                                            removed_by UUID REFERENCES employee(employee_id),
                                                            reason_removed VARCHAR(40) CHECK (reason_removed IN ('fault','weak','upgrade','seasonal','other')),
                                                            is_active BOOLEAN GENERATED ALWAYS AS (removed_at IS NULL) STORED,
                                                            created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_vbi_vehicle_active ON vehicle_battery_installation(vehicle_id) WHERE removed_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_battery_active_assignment
    ON vehicle_battery_installation(battery_id) WHERE removed_at IS NULL;

CREATE TABLE IF NOT EXISTS battery_test (
                                            test_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                            battery_id UUID NOT NULL REFERENCES battery(battery_id) ON DELETE CASCADE,
                                            vehicle_id UUID REFERENCES vehicle(vehicle_id),
                                            test_time TIMESTAMPTZ NOT NULL,
                                            odometer_km NUMERIC(12,2),
                                            voltage_open_circuit NUMERIC(5,2),
                                            voltage_cranking NUMERIC(5,2),
                                            cca_measured INTEGER,
                                            soc_percent NUMERIC(5,2),
                                            soi_percent NUMERIC(5,2),
                                            temperature_c NUMERIC(5,2),
                                            tester_model VARCHAR(60),
                                            result VARCHAR(20) CHECK (result IN ('good','weak','replace','charge','unknown')) DEFAULT 'good',
                                            notes TEXT,
                                            tested_by UUID REFERENCES employee(employee_id),
                                            created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_battery_test_batt_time ON battery_test(battery_id, test_time DESC);

CREATE TABLE IF NOT EXISTS battery_warranty_claim (
                                                      claim_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                      battery_id UUID NOT NULL REFERENCES battery(battery_id) ON DELETE CASCADE,
                                                      vehicle_id UUID REFERENCES vehicle(vehicle_id),
                                                      claim_date DATE NOT NULL,
                                                      claim_reason VARCHAR(120),
                                                      dealer_name VARCHAR(120),
                                                      status VARCHAR(20) CHECK (status IN ('submitted','approved','rejected','replaced','closed')) DEFAULT 'submitted',
                                                      resolution_notes TEXT,
                                                      replacement_battery_id UUID REFERENCES battery(battery_id),
                                                      created_by UUID REFERENCES employee(employee_id),
                                                      created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_battery_claim_batt ON battery_warranty_claim(battery_id, claim_date DESC);

/* ====================== 17) SERVICE ORDERS ============================= */

CREATE TABLE IF NOT EXISTS service_order (
                                             so_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                             vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
                                             project_id UUID REFERENCES project(project_id),
                                             maintenance_id UUID REFERENCES maintenance_record(maintenance_id),
                                             repair_job_id UUID REFERENCES repair_job(repair_job_id),
                                             so_number VARCHAR(100) UNIQUE NOT NULL,
                                             so_date DATE NOT NULL,
                                             requested_by UUID REFERENCES employee(employee_id),
                                             status VARCHAR(20) CHECK (status IN ('draft','approved','in_progress','completed','cancelled')) DEFAULT 'draft',
                                             notes TEXT,
                                             created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS service_receive_note (
                                                    srn_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                    so_id UUID REFERENCES service_order(so_id) ON DELETE SET NULL,
                                                    vehicle_id UUID REFERENCES vehicle(vehicle_id),
                                                    received_date DATE NOT NULL,
                                                    description TEXT,
                                                    cost_amount DECIMAL(12,2),
                                                    created_by UUID REFERENCES employee(employee_id),
                                                    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

/* ====================== 18) REVENUE & ANALYTICS ======================== */

CREATE TABLE IF NOT EXISTS revenue_record (
                                              revenue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                              project_id UUID REFERENCES project(project_id),
                                              vehicle_id UUID NOT NULL REFERENCES vehicle(vehicle_id),
                                              work_order_id UUID REFERENCES transport_work_order(work_order_id),
                                              revenue_date DATE NOT NULL,
                                              ownership_type VARCHAR(10) CHECK (ownership_type IN ('own','hire')) NOT NULL,
                                              revenue_type VARCHAR(20) CHECK (revenue_type IN ('rental','transport','overtime','standby')) NOT NULL,
                                              hours_worked DECIMAL(8,2),
                                              distance_km DECIMAL(10,2),
                                              trips_count INTEGER,
                                              base_amount DECIMAL(12,2) NOT NULL,
                                              fuel_cost DECIMAL(12,2) DEFAULT 0,
                                              driver_cost DECIMAL(12,2) DEFAULT 0,
                                              maintenance_cost DECIMAL(12,2) DEFAULT 0,
                                              other_cost DECIMAL(12,2) DEFAULT 0,
                                              total_revenue DECIMAL(12,2) GENERATED ALWAYS AS (base_amount) STORED,
                                              total_cost DECIMAL(12,2) GENERATED ALWAYS AS (fuel_cost + driver_cost + maintenance_cost + other_cost) STORED,
                                              gross_profit DECIMAL(12,2) GENERATED ALWAYS AS (base_amount - (fuel_cost + driver_cost + maintenance_cost + other_cost)) STORED,
                                              profit_margin DECIMAL(6,2) GENERATED ALWAYS AS (CASE WHEN base_amount>0 THEN ((base_amount - (fuel_cost + driver_cost + maintenance_cost + other_cost)) / base_amount)*100 ELSE 0 END) STORED,
                                              created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_rev_project_date ON revenue_record(project_id, revenue_date DESC);
CREATE INDEX IF NOT EXISTS idx_rev_vehicle_date ON revenue_record(vehicle_id, revenue_date DESC);
CREATE INDEX IF NOT EXISTS idx_rev_ownership ON revenue_record(ownership_type);

/* ====================== 19) AUDIT & DOCUMENT MANAGEMENT ==================== */

CREATE TABLE IF NOT EXISTS audit_log (
                                         audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                         user_id UUID REFERENCES app_user(user_id),
                                         employee_id UUID REFERENCES employee(employee_id),
                                         ip_address INET,
                                         user_agent TEXT,
                                         action VARCHAR(50) NOT NULL,
                                         entity_type VARCHAR(100) NOT NULL,
                                         entity_id UUID,
                                         entity_name VARCHAR(200),
                                         old_values JSONB,
                                         new_values JSONB,
                                         changed_fields TEXT[],
                                         timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                         request_id UUID,
                                         session_id UUID,
                                         notes TEXT,
                                         tags TEXT[]
);
CREATE INDEX IF NOT EXISTS idx_audit_ts ON audit_log(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_log(entity_type, entity_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_log(action, timestamp DESC);

CREATE TABLE IF NOT EXISTS document (
                                        document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                        document_type VARCHAR(50) NOT NULL,
                                        document_name VARCHAR(200) NOT NULL,
                                        document_number VARCHAR(100),
                                        entity_type VARCHAR(50) NOT NULL,
                                        entity_id UUID NOT NULL,
                                        file_path TEXT NOT NULL,
                                        file_size_bytes BIGINT,
                                        mime_type VARCHAR(100),
                                        issue_date DATE,
                                        expiry_date DATE,
                                        reminder_days_before INTEGER DEFAULT 30,
                                        reminder_sent BOOLEAN DEFAULT FALSE,
                                        is_verified BOOLEAN DEFAULT FALSE,
                                        verified_by UUID REFERENCES employee(employee_id),
                                        verified_date TIMESTAMPTZ,
                                        tags TEXT[],
                                        notes TEXT,
                                        uploaded_by UUID REFERENCES employee(employee_id),
                                        uploaded_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

/* ====================== 20) USER & ROLE MANAGEMENT ========================= */

CREATE TABLE IF NOT EXISTS app_user (
                                        user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                        employee_id UUID UNIQUE NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
                                        username VARCHAR(50) UNIQUE NOT NULL,
                                        email VARCHAR(120) UNIQUE NOT NULL,
                                        password_plain VARCHAR(255) NOT NULL,
                                        is_active BOOLEAN DEFAULT TRUE,
                                        is_locked BOOLEAN DEFAULT FALSE,
                                        failed_login_attempts INTEGER DEFAULT 0,
                                        last_login_at TIMESTAMPTZ,
                                        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                        updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_user_username ON app_user(username);
CREATE TRIGGER trg_user_upd BEFORE UPDATE ON app_user FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS role (
                                    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                    role_name VARCHAR(80) UNIQUE NOT NULL,
                                    description TEXT,
                                    is_active BOOLEAN DEFAULT TRUE,
                                    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS permission (
                                          permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                          permission_code VARCHAR(120) UNIQUE NOT NULL,
                                          description TEXT
);

CREATE TABLE IF NOT EXISTS role_permission (
                                               role_id UUID REFERENCES role(role_id) ON DELETE CASCADE,
                                               permission_id UUID REFERENCES permission(permission_id) ON DELETE CASCADE,
                                               PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS user_role (
                                         user_id UUID REFERENCES app_user(user_id) ON DELETE CASCADE,
                                         role_id UUID REFERENCES role(role_id) ON DELETE CASCADE,
                                         assigned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                         PRIMARY KEY (user_id, role_id)
);

CREATE TABLE IF NOT EXISTS login_history (
                                             history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                             user_id UUID REFERENCES app_user(user_id) ON DELETE CASCADE,
                                             login_time TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                             logout_time TIMESTAMPTZ,
                                             ip_address INET,
                                             user_agent TEXT,
                                             status VARCHAR(20) CHECK (status IN ('success','failed','locked','expired')) NOT NULL,
                                             failure_reason TEXT
);
CREATE INDEX IF NOT EXISTS idx_login_history_user ON login_history(user_id, login_time DESC);

CREATE TABLE IF NOT EXISTS user_session (
                                            session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                            user_id UUID NOT NULL REFERENCES app_user(user_id) ON DELETE CASCADE,
                                            session_token VARCHAR(255) UNIQUE NOT NULL,
                                            created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                            last_activity TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                                            expires_at TIMESTAMPTZ NOT NULL,
                                            is_active BOOLEAN DEFAULT TRUE
);
CREATE INDEX IF NOT EXISTS idx_user_session_user ON user_session(user_id, expires_at);

/* ====================== 21) ENHANCED REPORTING VIEWS ======================= */

-- Project-wise Inventory Summary
CREATE OR REPLACE VIEW project_inventory_summary AS
SELECT
    p.project_id,
    p.project_code,
    p.project_name,
    i.item_id,
    i.item_code,
    i.item_name,
    ic.category_name,
    SUM(pi.current_quantity) as total_quantity,
    SUM(pi.reserved_quantity) as reserved_quantity,
    SUM(pi.available_quantity) as available_quantity,
    AVG(COALESCE(ib.unit_cost, i.average_cost)) as avg_unit_cost,
    SUM(pi.current_quantity * COALESCE(ib.unit_cost, i.average_cost, 0)) as total_value
FROM project p
         CROSS JOIN inventory_item i
         LEFT JOIN project_inventory pi ON p.project_id = pi.project_id AND i.item_id = pi.item_id
         LEFT JOIN inventory_category ic ON i.category_id = ic.category_id
         LEFT JOIN inventory_batch ib ON pi.batch_id = ib.batch_id
WHERE i.is_active = true
GROUP BY p.project_id, p.project_code, p.project_name, i.item_id, i.item_code, i.item_name, ic.category_name;

-- Item-wise Transaction History
CREATE OR REPLACE VIEW item_transaction_history AS
SELECT
    i.item_id,
    i.item_code,
    i.item_name,
    it.transaction_id,
    it.transaction_date,
    it.transaction_type,
    it.quantity,
    it.unit_cost,
    it.total_value,
    p.project_name,
    v.vehicle_code,
    it.reference_type,
    it.notes,
    e.first_name || ' ' || e.last_name as created_by
FROM inventory_transaction it
         JOIN inventory_item i ON it.item_id = i.item_id
         LEFT JOIN project p ON it.project_id = p.project_id
         LEFT JOIN vehicle v ON it.vehicle_id = v.vehicle_id
         LEFT JOIN employee e ON it.created_by = e.employee_id
ORDER BY it.transaction_date DESC, it.created_at DESC;

-- FIXED: Vehicle Running Efficiency Report
CREATE OR REPLACE VIEW vehicle_running_efficiency AS
SELECT
    v.vehicle_id,
    v.vehicle_code,
    v.registration_number,
    EXTRACT(YEAR FROM vrl.log_date) as year,
    EXTRACT(MONTH FROM vrl.log_date) as month,
    COUNT(vrl.log_id) as working_days,
    SUM(vrl.total_distance) as total_distance_km,
    SUM(vrl.engine_hours) as total_engine_hours,
    SUM(COALESCE(vrl.fuel_consumed, 0)) as total_fuel_consumed,
    CASE
        WHEN SUM(COALESCE(vrl.fuel_consumed, 0)) > 0 THEN
            ROUND(SUM(vrl.total_distance) / SUM(vrl.fuel_consumed), 2)
        ELSE NULL
        END as avg_fuel_efficiency,
    SUM(voc.amount) as total_operating_cost,
    CASE
        WHEN SUM(vrl.total_distance) > 0 THEN
            ROUND(SUM(voc.amount) / SUM(vrl.total_distance), 2)
        ELSE NULL
        END as cost_per_km
FROM vehicle v
         LEFT JOIN vehicle_running_log vrl ON v.vehicle_id = vrl.vehicle_id
         LEFT JOIN vehicle_operating_cost voc ON v.vehicle_id = voc.vehicle_id
    AND EXTRACT(YEAR FROM voc.cost_date) = EXTRACT(YEAR FROM vrl.log_date)
    AND EXTRACT(MONTH FROM voc.cost_date) = EXTRACT(MONTH FROM vrl.log_date)
GROUP BY v.vehicle_id, v.vehicle_code, v.registration_number, year, month;

-- AI Maintenance Prediction Dashboard
CREATE OR REPLACE VIEW maintenance_prediction_dashboard AS
SELECT
    v.vehicle_id,
    v.vehicle_code,
    v.registration_number,
    p.project_name,
    mp.prediction_id,
    mp.predicted_component,
    mp.prediction_type,
    mp.predicted_date,
    mp.confidence_score,
    mp.current_risk_level,
    mp.recommended_actions,
    vhs.overall_score as vehicle_health_score,
    (mp.predicted_date - CURRENT_DATE) as days_until_predicted
FROM maintenance_prediction mp
         JOIN vehicle v ON mp.vehicle_id = v.vehicle_id
         LEFT JOIN project p ON v.current_project_id = p.project_id
         LEFT JOIN vehicle_health_score vhs ON v.vehicle_id = vhs.vehicle_id
    AND vhs.calculation_date = (SELECT MAX(calculation_date) FROM vehicle_health_score WHERE vehicle_id = v.vehicle_id)
WHERE mp.is_active = true AND mp.acknowledged = false
ORDER BY mp.current_risk_level DESC, mp.confidence_score DESC;

-- FIXED: Employee Progress and Performance View (Resolved 'status' column ambiguity)
CREATE OR REPLACE VIEW employee_progress_tracking AS
SELECT
    e.employee_id,
    e.employee_code,
    e.first_name || ' ' || e.last_name as employee_name,
    eg.grade_name,
    COUNT(DISTINCT eta.assessment_id) as skills_assessed,
    (SELECT COUNT(*) FROM employee_skill_assessment esa WHERE esa.employee_id = e.employee_id AND esa.skill_level IN ('advanced','expert')) as advanced_skills,
    COUNT(DISTINCT etr.training_record_id) as trainings_completed,
    AVG(epr.performance_score) as avg_performance_score,
    COUNT(DISTINCT a.attendance_id) as attendance_days,
    COUNT(DISTINCT ec.complaint_id) as complaints_received,
    (SELECT COUNT(*) FROM employee_complaint ec2 WHERE ec2.assigned_to = e.employee_id AND ec2.status = 'resolved') as complaints_resolved
FROM employee e
         LEFT JOIN employee_grade eg ON e.grade_id = eg.grade_id
         LEFT JOIN employee_skill_assessment eta ON e.employee_id = eta.employee_id
         LEFT JOIN employee_training_record etr ON e.employee_id = etr.employee_id AND etr.status = 'completed'
         LEFT JOIN employee_performance_review epr ON e.employee_id = epr.employee_id
         LEFT JOIN attendance a ON e.employee_id = a.employee_id AND a.status = 'present'
         LEFT JOIN employee_complaint ec ON e.employee_id = ec.employee_id
GROUP BY e.employee_id, e.employee_code, employee_name, eg.grade_name;

-- Vehicle Utilization Report
CREATE OR REPLACE VIEW vehicle_utilization_report AS
SELECT
    v.vehicle_id,
    v.vehicle_code,
    v.registration_number,
    v.ownership_type,
    p.project_name,
    COUNT(DISTINCT va.assignment_id) as assignment_count,
    SUM(COALESCE(vda.distance_km, 0)) as total_distance_km,
    SUM(COALESCE(vda.engine_hours, 0)) as total_engine_hours,
    COUNT(DISTINCT vda.activity_date) as working_days
FROM vehicle v
         LEFT JOIN vehicle_assignment va ON v.vehicle_id = va.vehicle_id AND va.status = 'active'
         LEFT JOIN project p ON v.current_project_id = p.project_id
         LEFT JOIN vehicle_daily_activity vda ON v.vehicle_id = vda.vehicle_id
GROUP BY v.vehicle_id, v.vehicle_code, v.registration_number, v.ownership_type, p.project_name;

-- Vehicle Filter Status View
CREATE OR REPLACE VIEW vehicle_filter_status AS
SELECT
    v.vehicle_id,
    v.vehicle_code,
    vf.filter_id,
    ft.filter_name,
    ft.filter_code,
    vf.installed_date,
    vf.installed_odometer_km,
    vf.installed_engine_hours,
    v.current_odometer_km,
    v.total_engine_hours,
    vf.recommended_replacement_km,
    vf.recommended_replacement_hours,
    CASE
        WHEN vf.recommended_replacement_km IS NOT NULL THEN
            ROUND(((v.current_odometer_km - vf.installed_odometer_km) / vf.recommended_replacement_km) * 100, 2)
        WHEN vf.recommended_replacement_km IS NULL THEN NULL
        END as km_usage_percentage,
    CASE
        WHEN vf.recommended_replacement_hours IS NOT NULL THEN
            ROUND(((v.total_engine_hours - vf.installed_engine_hours) / vf.recommended_replacement_hours) * 100, 2)
        WHEN vf.recommended_replacement_hours IS NULL THEN NULL
        END as hours_usage_percentage,
    vf.status
FROM vehicle_filter vf
         JOIN vehicle v ON vf.vehicle_id = v.vehicle_id
         JOIN vehicle_filter_type ft ON vf.filter_type_id = ft.filter_type_id
WHERE vf.status = 'active';

-- Vehicle Health Overview
CREATE OR REPLACE VIEW vehicle_health_overview AS
SELECT
    v.vehicle_id,
    v.vehicle_code,
    v.registration_number,
    p.project_name,
    vhs.overall_score,
    vhs.engine_health,
    vhs.transmission_health,
    vhs.brake_health,
    vhs.tire_health,
    vhs.electrical_health,
    vhs.maintenance_readiness_score,
    COUNT(mp.prediction_id) as active_predictions,
    COUNT(CASE WHEN mp.current_risk_level IN ('high','critical') THEN 1 END) as high_risk_predictions
FROM vehicle v
         LEFT JOIN project p ON v.current_project_id = p.project_id
         LEFT JOIN vehicle_health_score vhs ON v.vehicle_id = vhs.vehicle_id
    AND vhs.calculation_date = (SELECT MAX(calculation_date) FROM vehicle_health_score WHERE vehicle_id = v.vehicle_id)
         LEFT JOIN maintenance_prediction mp ON v.vehicle_id = mp.vehicle_id AND mp.is_active = true
GROUP BY v.vehicle_id, v.vehicle_code, v.registration_number, p.project_name, vhs.overall_score, vhs.engine_health,
         vhs.transmission_health, vhs.brake_health, vhs.tire_health, vhs.electrical_health, vhs.maintenance_readiness_score;

-- FIXED: Monthly Fleet Performance Dashboard
CREATE OR REPLACE VIEW fleet_performance_monthly AS
SELECT
    EXTRACT(YEAR FROM vrl.log_date) as year,
    EXTRACT(MONTH FROM vrl.log_date) as month,
    COUNT(DISTINCT vrl.vehicle_id) as active_vehicles,
    SUM(vrl.total_distance) as total_km,
    AVG(vre.avg_fuel_efficiency) as avg_fleet_efficiency,
    SUM(vre.total_operating_cost) as total_cost,
    CASE
        WHEN SUM(vrl.total_distance) > 0 THEN
            SUM(vre.total_operating_cost) / SUM(vrl.total_distance)
        ELSE NULL
        END as cost_per_km,
    COUNT(DISTINCT br.breakdown_id) as breakdown_count
FROM vehicle_running_log vrl
         LEFT JOIN vehicle_running_efficiency vre ON vrl.vehicle_id = vre.vehicle_id
    AND EXTRACT(YEAR FROM vrl.log_date) = vre.year
    AND EXTRACT(MONTH FROM vrl.log_date) = vre.month
         LEFT JOIN breakdown_record br ON vrl.vehicle_id = br.vehicle_id
    AND EXTRACT(YEAR FROM br.breakdown_at) = EXTRACT(YEAR FROM vrl.log_date)
    AND EXTRACT(MONTH FROM br.breakdown_at) = EXTRACT(MONTH FROM vrl.log_date)
GROUP BY year, month
ORDER BY year DESC, month DESC;

-- FIXED: Maintenance Cost Analysis
CREATE OR REPLACE VIEW maintenance_cost_analysis AS
SELECT
    v.vehicle_id,
    v.registration_number,
    v.ownership_type,
    EXTRACT(YEAR FROM mr.start_time) as year,
    COUNT(mr.maintenance_id) as maintenance_count,
    SUM(mr.total_cost) as total_maintenance_cost,
    AVG(mr.total_cost) as avg_maintenance_cost,
    SUM(vrl.total_distance) as distance_covered,
    CASE
        WHEN SUM(vrl.total_distance) > 0 THEN
            SUM(mr.total_cost) / SUM(vrl.total_distance)
        ELSE 0
        END as maintenance_cost_per_km
FROM vehicle v
         LEFT JOIN maintenance_record mr ON v.vehicle_id = mr.vehicle_id
         LEFT JOIN vehicle_running_log vrl ON v.vehicle_id = vrl.vehicle_id
    AND EXTRACT(YEAR FROM vrl.log_date) = EXTRACT(YEAR FROM mr.start_time)
GROUP BY v.vehicle_id, v.registration_number, v.ownership_type, year;

/* ====================== 22) TRIGGERS & FUNCTIONS =========================== */

-- Function to update vehicle odometer
CREATE OR REPLACE FUNCTION update_vehicle_odometer()
    RETURNS TRIGGER AS $$
BEGIN
    IF NEW.end_odometer_km IS NOT NULL AND NEW.end_odometer_km > (SELECT current_odometer_km FROM vehicle WHERE vehicle_id = NEW.vehicle_id) THEN
        UPDATE vehicle
        SET current_odometer_km = NEW.end_odometer_km,
            updated_at = CURRENT_TIMESTAMP
        WHERE vehicle_id = NEW.vehicle_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for vehicle daily activity
DROP TRIGGER IF EXISTS trg_vehicle_odometer_update ON vehicle_daily_activity;
CREATE TRIGGER trg_vehicle_odometer_update
    AFTER INSERT OR UPDATE ON vehicle_daily_activity
    FOR EACH ROW EXECUTE FUNCTION update_vehicle_odometer();

-- Function to calculate fuel efficiency
CREATE OR REPLACE FUNCTION calculate_fuel_efficiency()
    RETURNS TRIGGER AS $$
BEGIN
    IF NEW.distance_since_last_fill IS NOT NULL AND NEW.quantity_liters IS NOT NULL
        AND NEW.distance_since_last_fill > 0 AND NEW.quantity_liters > 0 THEN
        NEW.fuel_efficiency := ROUND(NEW.distance_since_last_fill / NEW.quantity_liters, 3);
    END IF;

    -- AI-based anomaly detection (simplified version)
    IF NEW.fuel_efficiency IS NOT NULL THEN
        SELECT AVG(fuel_efficiency)
        INTO NEW.expected_consumption_l
        FROM fuel_transaction
        WHERE vehicle_id = NEW.vehicle_id
          AND fuel_efficiency IS NOT NULL
          AND transaction_time > CURRENT_DATE - INTERVAL '30 days';

        IF NEW.expected_consumption_l > 0 THEN
            NEW.variance_percent := ROUND(ABS((NEW.quantity_liters - NEW.expected_consumption_l) / NEW.expected_consumption_l) * 100, 2);
            IF NEW.variance_percent > 20 THEN
                NEW.anomaly_detected := TRUE;
                NEW.anomaly_type := CASE WHEN NEW.quantity_liters > NEW.expected_consumption_l THEN 'overconsumption' ELSE 'underconsumption' END;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for fuel transactions
DROP TRIGGER IF EXISTS trg_fuel_efficiency ON fuel_transaction;
CREATE TRIGGER trg_fuel_efficiency
    BEFORE INSERT OR UPDATE ON fuel_transaction
    FOR EACH ROW EXECUTE FUNCTION calculate_fuel_efficiency();

-- Function to suggest next service
CREATE OR REPLACE FUNCTION suggest_next_service()
    RETURNS TRIGGER AS $$
DECLARE
    int_km INT;
    int_months INT;
BEGIN
    SELECT interval_km, interval_months
    INTO int_km, int_months
    FROM maintenance_standard
    WHERE standard_id = NEW.standard_id;

    IF int_km IS NOT NULL AND NEW.odometer_km IS NOT NULL THEN
        NEW.next_service_odometer_km := NEW.odometer_km + int_km;
    END IF;

    IF int_months IS NOT NULL AND NEW.start_time IS NOT NULL THEN
        NEW.next_service_date := (NEW.start_time + (int_months || ' months')::INTERVAL)::DATE;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_suggest_next_service ON maintenance_record;
CREATE TRIGGER trg_suggest_next_service
    BEFORE INSERT ON maintenance_record
    FOR EACH ROW EXECUTE FUNCTION suggest_next_service();

-- Function to update project inventory on transactions
CREATE OR REPLACE FUNCTION update_project_inventory()
    RETURNS TRIGGER AS $$
BEGIN
    -- Update project inventory based on transaction type
    IF NEW.transaction_type IN ('purchase', 'return') THEN
        INSERT INTO project_inventory (project_id, item_id, batch_id, current_quantity)
        VALUES (NEW.project_id, NEW.item_id, NEW.batch_id, NEW.quantity)
        ON CONFLICT (project_id, item_id, batch_id)
            DO UPDATE SET
                          current_quantity = project_inventory.current_quantity + NEW.quantity,
                          last_updated = CURRENT_TIMESTAMP;

    ELSIF NEW.transaction_type IN ('issue', 'write_off') THEN
        UPDATE project_inventory
        SET current_quantity = current_quantity - NEW.quantity,
            last_updated = CURRENT_TIMESTAMP
        WHERE project_id = NEW.project_id
          AND item_id = NEW.item_id
          AND (batch_id = NEW.batch_id OR NEW.batch_id IS NULL);

    ELSIF NEW.transaction_type = 'transfer' THEN
        -- Deduct from source project
        UPDATE project_inventory
        SET current_quantity = current_quantity - NEW.quantity,
            last_updated = CURRENT_TIMESTAMP
        WHERE project_id = NEW.project_id
          AND item_id = NEW.item_id
          AND batch_id = NEW.batch_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_inventory_transaction ON inventory_transaction;
CREATE TRIGGER trg_inventory_transaction
    AFTER INSERT ON inventory_transaction
    FOR EACH ROW EXECUTE FUNCTION update_project_inventory();

-- Function for low stock alerts
CREATE OR REPLACE FUNCTION check_inventory_alerts()
    RETURNS TRIGGER AS $$
BEGIN
    -- Check for low stock
    IF NEW.current_quantity <= (SELECT reorder_level FROM inventory_item WHERE item_id = NEW.item_id) THEN
        INSERT INTO inventory_alert (item_id, project_id, alert_type, alert_level, current_quantity, threshold_quantity, message)
        VALUES (NEW.item_id, NEW.project_id, 'low_stock', 'warning', NEW.current_quantity,
                (SELECT reorder_level FROM inventory_item WHERE item_id = NEW.item_id),
                'Low stock alert for item: ' || (SELECT item_name FROM inventory_item WHERE item_id = NEW.item_id));
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_inventory_alert ON project_inventory;
CREATE TRIGGER trg_inventory_alert
    AFTER INSERT OR UPDATE ON project_inventory
    FOR EACH ROW EXECUTE FUNCTION check_inventory_alerts();

-- Function to compute battery warranty expiry
CREATE OR REPLACE FUNCTION battery_compute_warranty_expiry()
    RETURNS TRIGGER AS $$
BEGIN
    IF NEW.purchase_date IS NOT NULL AND NEW.warranty_months IS NOT NULL THEN
        NEW.warranty_expiry_date := (NEW.purchase_date + make_interval(months => NEW.warranty_months))::date;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_battery_warranty_expiry ON battery;
CREATE TRIGGER trg_battery_warranty_expiry
    BEFORE INSERT OR UPDATE OF purchase_date, warranty_months ON battery
    FOR EACH ROW EXECUTE FUNCTION battery_compute_warranty_expiry();

/* ====================== 23) DATA RETENTION POLICIES ======================== */

-- NEW: Data Retention Policies
CREATE TABLE IF NOT EXISTS data_retention_policy (
                                                     policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                     table_name VARCHAR(100) NOT NULL,
                                                     retention_months INTEGER NOT NULL,
                                                     archive_before_delete BOOLEAN DEFAULT TRUE,
                                                     is_active BOOLEAN DEFAULT TRUE,
                                                     created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Example retention policies
INSERT INTO data_retention_policy (policy_id, table_name, retention_months, archive_before_delete, is_active) VALUES
                                                                                                                  (gen_random_uuid(), 'audit_log', 36, true, true),
                                                                                                                  (gen_random_uuid(), 'fuel_transaction', 24, true, true),
                                                                                                                  (gen_random_uuid(), 'vehicle_running_log', 12, true, true),
                                                                                                                  (gen_random_uuid(), 'inventory_transaction', 24, true, true),
                                                                                                                  (gen_random_uuid(), 'maintenance_record', 60, true, true)
ON CONFLICT DO NOTHING;

/* ====================== 24) INITIAL DATA =================================== */

-- Insert maintenance strategies
INSERT INTO maintenance_strategy (strategy_id, strategy_name, strategy_type, description) VALUES
                                                                                              (gen_random_uuid(), 'Preventive Maintenance', 'preventive', 'Scheduled maintenance based on manufacturer recommendations'),
                                                                                              (gen_random_uuid(), 'Corrective Maintenance', 'corrective', 'Response to breakdowns and defects'),
                                                                                              (gen_random_uuid(), 'Predictive Maintenance', 'predictive', 'Condition-based interventions'),
                                                                                              (gen_random_uuid(), 'Condition Based Maintenance', 'condition_based', 'Maintenance based on actual equipment condition')
ON CONFLICT DO NOTHING;

-- Insert hire deduction types
INSERT INTO hire_deduction_type (deduction_type_id, code, label) VALUES
                                                                     (gen_random_uuid(), 'FUEL_WET', 'Fuel deduction (Wet basis)'),
                                                                     (gen_random_uuid(), 'FUEL_ABNORMAL', 'Abnormal fuel deduction (Dry basis)'),
                                                                     (gen_random_uuid(), 'DAMAGE', 'Damage/Repairs'),
                                                                     (gen_random_uuid(), 'LATE_SUBMIT', 'Late submission'),
                                                                     (gen_random_uuid(), 'ADVANCE_RECOVERY', 'Advance recovery'),
                                                                     (gen_random_uuid(), 'OTHER', 'Other')
ON CONFLICT DO NOTHING;

-- Insert common vehicle categories
INSERT INTO vehicle_category (category_id, category_name, category_code, category_type, description) VALUES
                                                                                                         (gen_random_uuid(), 'Light Vehicles', 'LIGHT', 'light_vehicle', 'Cars, vans, pickup trucks'),
                                                                                                         (gen_random_uuid(), 'Heavy Vehicles', 'HEAVY', 'heavy_vehicle', 'Trucks, buses, heavy equipment carriers'),
                                                                                                         (gen_random_uuid(), 'Excavators', 'EXCAVATOR', 'excavator', 'Various types of excavators'),
                                                                                                         (gen_random_uuid(), 'Generators', 'GENERATOR', 'generator', 'Power generators of different capacities'),
                                                                                                         (gen_random_uuid(), 'Compressors', 'COMPRESSOR', 'compressor', 'Air compressors for construction')
ON CONFLICT DO NOTHING;

/* ====================== 25) PERFORMANCE INDEXES ============================ */

-- Additional performance indexes
CREATE INDEX IF NOT EXISTS idx_employee_skills ON employee_skill_assessment(employee_id, skill_level);
CREATE INDEX IF NOT EXISTS idx_employee_training ON employee_training_record(employee_id, status);
CREATE INDEX IF NOT EXISTS idx_employee_complaints ON employee_complaint(employee_id, status, priority);
CREATE INDEX IF NOT EXISTS idx_payroll_employee_period ON payroll(employee_id, payroll_year, payroll_month);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_vehicle_maintenance_composite ON maintenance_record(vehicle_id, start_time, status);
CREATE INDEX IF NOT EXISTS idx_inventory_composite ON inventory_transaction(item_id, transaction_date, transaction_type);
CREATE INDEX IF NOT EXISTS idx_fuel_composite ON fuel_transaction(vehicle_id, transaction_date, anomaly_detected);

/* ====================== 26) FINAL FIXES ==================================== */

-- Ensure maintenance_record has the status column with correct values
DO $$
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = 'maintenance_record'
              AND column_name = 'status'
        ) THEN
            ALTER TABLE maintenance_record
                ADD COLUMN status VARCHAR(20)
                    CHECK (status IN ('planned','in_progress','completed','approved','cancelled'))
                    DEFAULT 'in_progress';
        END IF;
    END$$;

-- Recreate the composite index that references status
DROP INDEX IF EXISTS idx_vehicle_maintenance_composite;
CREATE INDEX IF NOT EXISTS idx_vehicle_maintenance_composite
    ON maintenance_record(vehicle_id, start_time, status);

/* =========================================================================== */