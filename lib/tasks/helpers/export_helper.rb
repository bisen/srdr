module ExportHelper
  class ProjectWrapper
    def initialize(project)
      @p = project

      #key_questions_projects
      @kqparr = []
      @p.key_questions.each do |kq|
        @kqparr << KeyQuestionsProjectWrapper.new(kq)
      end

      @puarr = []
      @purdict = {}
      @p.users.each do |u|
        pu = ProjectsUserWrapper.new(@p, u)
        #THIS IS WEIRD
        pur = ProjectsUsersRoleWrapper.new(pu, pu.roles.first)
        @purdict[u.id] = pur
        @puarr << pu
      end

      @efparr = []
      @efpdict = {}
      @p.extraction_forms.where(:is_diagnostic => 0).each do |ef|
        efp = ExtractionFormsProjectWrapper.new(ef, @p)
        @efparr << efp
        @efpdict[ef.id] = efp
      end

      #citations_projects
      @cparr = []
      @extractions = []
      @p.studies.each do |s|
        cp = CitationsProjectWrapper.new(s, self)
        @cparr << cp

        s.study_extraction_forms.each do |sef|
          pur = @purdict[s.creator_id]
          efp = @efpdict[sef.extraction_form_id]
          @extractions << ExtractionWrapper.new(cp, pur, efp)
        end
      end
    end

    def id; @p.id end
    def name; @p.title || "" end
    def description; @p.description || "" end
    def attribution; @p.attribution || "" end
    def methodology_description; @p.methodology || "" end
    def prospero; @p.prospero_id || "" end
    def doi; @p.doi_id || "" end
    def notes; @p.notes || ""  end
    def funding_source; @p.funding_source || "" end
    def key_questions_projects; @kqparr end
    def tasks; [] end #??????????
    def projects_users; @puarr end
    def citations_projects; @cparr end
    def extraction_forms_projects; @efparr end
    def extractions; @extractions end
  end

  class KeyQuestionsProjectWrapper
    def initialize(kq)
      @kq = KeyQuestionWrapper.new kq
    end

    def key_question; @kq end
  end

  class KeyQuestionWrapper
    def initialize(kq)
      # srdr kq
      @kq = kq
    end

    def id; @kq.id end
    def name; @kq.question end
  end

  class UserWrapper
    def initialize(user)
      @id = user.id
      @u = user
      @profile = ProfileWrapper.new user
    end

    def id; @id end
    def email; @u.email end
    def profile; @profile end
  end

  class OrganizationWrapper
    @@id_counter = 1
    def initialize(name)
      @id = @@id_counter
      @@id_counter += 1
      @name = name
    end

    def name; @name end
    def id; @id end
  end

  class ProfileWrapper
    def initialize(user)
      @u = user
      @o = OrganizationWrapper.new(@u.organization)
    end

    def username
      if @u.login != @u.email
        @u.login
      else
        @u.fname + @u.lname
      end
    end

    def first_name; @u.fname end
    def middle_name; "" end
    def last_name; @u.lname end
    def time_zone; "" end #????
    def organization; @o end
    def degrees; [] end
  end

  class ProjectsUsersRoleWrapper
    # only needed in one place
    attr_accessor :user, :role, :projects_user
    def initialize(pu, role)
      @projects_user = pu
      @user = pu.user
      @role = role
    end
  end

  class ProjectsUserWrapper
    @@id_counter = 1
    def initialize(project, user)
      @id = @@id_counter
      @@id_counter += 1
      @project = project
      @user = UserWrapper.new user

      #roles
      @roles = []
      UserProjectRole.where(user_id: user.id, project_id: project.id).each do |upr|
        if upr.role == "lead"
          @roles << RoleWrapper.new("Leader")
        else
          @roles << RoleWrapper.new("Contributor")
        end
      end
    end

    def id; @id end
    def project; @project end
    def user; @user end
    def projects_users_term_groups_colors; [] end
    def roles; @roles end
  end

  class RoleWrapper
    @@id_dict = { "Leader" => 1,
                  "Consolidator" => 2,
                  "Contributor" => 3,
                  "Auditor" => 4 }

    def initialize name
      @name = name
      @id = @@id_dict[name]
    end

    def id; @id end
    def name; @name end
  end

  class CitationsProjectWrapper
    def initialize s, p
      @id = s.id
      @c = CitationWrapper.new(s.get_primary_publication)
      @p = p
    end

    def id; @id end
    def citation; @c end
    def project; @p end
    def labels; [] end
    def taggings; [] end
    def notes; [] end
    def self.get_cp_id(c,p); @@id_dict[c.id.to_s + " - " + p.id.to_s] end
  end

  class CitationWrapper
    attr_accessor :id, :name, :abstract, :refman, :pmid, :keywords, :authors, :journal
    @@id_counter = 1
    def initialize pp
      #we're ignoring secondary publications?
      @id = @@id_counter
      @@id_counter += 1
      if pp.nil?
        @name = ""
        @abstract = ""
        @pmid = ""
      else
        @name = pp.title
        @abstract = pp.abstract
        @pmid = pp.pmid
      end
      @refman = ""
      @journal = JournalWrapper.new pp
      @keywords = [] ## TODO: SEPARATE KWs
      @authors = [] ## TODO: SEPARATE AUTHORs
    end
  end

  class JournalWrapper
    attr_accessor :id, :name, :volume, :issue
    def initialize pp
      @id = 1 #doesnt matter?
      if pp.nil?
        @name = ""
        @volume = ""
        @issue = ""
      else
        @name = pp.journal
        @volume = pp.volume
        @issue = pp.issue
      end
    end
  end

  class ExtractionFormsProjectWrapper
    attr_accessor :t1_efps, :t2_efps, :other_efps
    def initialize ef, p
      @ef = ef
      @p = p

      @t1_efps = []
      @t2_efps = []
      @other_efps = []

      arms_efps = nil
      outcomes_efps = nil
      diagnostic_tests_efps = nil

      ef.extraction_form_sections.where( included: true, section_name: ["adverse","arm_details","arms","baselines","design","outcome_details","outcomes","quality","results"] ).each do |s|
        efps = ExtractionFormsProjectsSectionWrapper.new(s)
        case s.section_name
        when "arms"
          @t1_efps << efps
          arms_efps = efps
        when "outcomes"
          @t1_efps << efps
          outcomes_efps = efps
        when "diagnostic_tests"
          @t1_efps << efps
          diagnostic_tests_efps = efps
        when "arm_details","outcome_details", "quality_details", "diagnostic_test_details"
          @t2_efps << efps
        else
          @other_efps << efps
        end
      end

      @t2_efps.each do |efps|
        case efps.efs.section_name
        when "arm_details"
          if EfSectionOption.where(extraction_form_id: ef.id, section: "arm_detail").first.by_arm
            efps.link_to_type1 = arms_efps
          end
        when "outcome_details", "quality_details"
          if EfSectionOption.where(extraction_form_id: ef.id, section: "outcome_detail").first.by_outcome
            efps.link_to_type1 = outcomes_efps
          end
        when "diagnostic_test_details"
          if EfSectionOption.where(extraction_form_id: ef.id, section: "diagnostic_test").first.by_diagnostic_test
            efps.link_to_type1 = diagnostic_tests_efps
          end
        end
      end

      # ArmDetails -> Arms
      # OutcomeDetails -> Outcomes
      # QualityDetails -> Outcomes
      # DiagnosticTestDetails -> DiagnosticTests
      # AdverseEventColumns -> AdverseEvents

    end

    def id; @ef.id end
    def extraction_forms_projects_sections; @t1_efps + @t2_efps + @other_efps end
  end

  class ExtractionFormsProjectsSectionWrapper
    attr_accessor :id, :efs, :link_to_type1, :extraction_forms_projects_section_option, :extraction_forms_projects_section_type, :extraction_forms_projects_section_option, :extraction_forms_projects_sections_type1s, :ordering, :section, :questions
    def initialize efs
      @id = efs.id
      @efs = efs
      @ordering = OrderingWrapper.new 1 ##TODO: ALL OF THE POSITIONS ARE THE SAME
      @extraction_forms_projects_sections_type1s = []
      @link_to_type1 = nil## TODO: link to right section
      @questions = []
      case efs.section_name
      when "adverse"
        @extraction_forms_projects_section_option #TODO What to do with this
        @section = SectionWrapper.new "Adverse Events"
        @extraction_forms_projects_section_type = ExtractionFormsProjectsSectionTypeWrapper.new "Type 1"
        AdverseEvent.where( extraction_form_id: efs.extraction_form.id ).each do |ae|
          @extraction_forms_projects_sections_type1s << ExtractionFormsProjectsSectionsType1Wrapper.new(ae.title, ae.description)
        end
      when "arm_details"
        @section = SectionWrapper.new "Arm Details"
        @extraction_forms_projects_section_type = ExtractionFormsProjectsSectionTypeWrapper.new "Type 2"
        ArmDetail.where(extraction_form_id: efs.extraction_form.id).order(question_number: :asc).each do |ad|
          question = QuestionWrapper.new(ad)
          @questions << question
          question.subquestions.each do |sq|
            @questions << sq
          end
        end
      when "arms"
        @section = SectionWrapper.new "Arms"
        @extraction_forms_projects_section_type = ExtractionFormsProjectsSectionTypeWrapper.new "Type 1"

        ExtractionFormArm.where( extraction_form_id: efs.extraction_form.id ).each do |efa|
          @extraction_forms_projects_sections_type1s << ExtractionFormsProjectsSectionsType1Wrapper.new(efa.name, efa.description)
        end
      when "diagnostic_test_details"
        @section = SectionWrapper.new "Diagnostic Test Details"
        @extraction_forms_projects_section_type = ExtractionFormsProjectsSectionTypeWrapper.new "Type 2"
        DiagnosticTestDetail.where(extraction_form_id: efs.extraction_form.id).order(question_number: :asc).each do |dtd|
          question = QuestionWrapper.new(dtd)
          @questions << question
          question.subquestions.each do |sq|
            @questions << sq
          end
        end
      when "diagnostic_tests"
        @section = SectionWrapper.new "Diagnostic Tests"
        @extraction_forms_projects_section_type = ExtractionFormsProjectsSectionTypeWrapper.new "Type 1"

        ExtractionFormDiagnosticTest.where( extraction_form_id: efs.extraction_form.id ).each do |efdt|
          @extraction_forms_projects_sections_type1s << ExtractionFormsProjectsSectionsType1Wrapper.new(efdt.title, efdt.description)
        end

      when "baselines"
        @section = SectionWrapper.new "Baseline Data"
        @extraction_forms_projects_section_type = ExtractionFormsProjectsSectionTypeWrapper.new "Type 2"
        BaselineCharacteristic.where( extraction_form_id: efs.extraction_form.id ).each do |bc|
          question = QuestionWrapper.new(bc)
          @questions << question
          question.subquestions.each do |sq|
            @questions << sq
          end
        end
      when "design"
        @section = SectionWrapper.new "Design Details"
        @extraction_forms_projects_section_type = ExtractionFormsProjectsSectionTypeWrapper.new "Type 2"
        DesignDetail.where( extraction_form_id: efs.extraction_form.id ).each do |dd|
          question = QuestionWrapper.new(dd)
          @questions << question
          question.subquestions.each do |sq|
            @questions << sq
          end
        end
      when "outcome_details"
        @section = SectionWrapper.new "Outcome Details"
        @extraction_forms_projects_section_type = ExtractionFormsProjectsSectionTypeWrapper.new "Type 2"
        OutcomeDetail.where( extraction_form_id: efs.extraction_form.id ).each do |od|
          question = QuestionWrapper.new(od)
          @questions << question
          question.subquestions.each do |sq|
            @questions << sq
          end
        end
      when "outcomes"
        @section = SectionWrapper.new "Outcomes"
        @extraction_forms_projects_section_type = ExtractionFormsProjectsSectionTypeWrapper.new "Type 1"
        ExtractionFormOutcomeName.where( extraction_form_id: efs.extraction_form.id ).each do |efo|
          @extraction_forms_projects_sections_type1s << ExtractionFormsProjectsSectionsType1Wrapper.new(efo.title, efo.note)
        end
      when "quality"
        @section = SectionWrapper.new "Quality"
        @extraction_forms_projects_section_type = ExtractionFormsProjectsSectionTypeWrapper.new "Type 2"
        QualityDetail.where( extraction_form_id: efs.extraction_form.id ).each do |qd|
          question = QuestionWrapper.new(qd)
          @questions << question
          question.subquestions.each do |sq|
            @questions << sq
          end
        end
      when "results"
        @section = SectionWrapper.new "Results"
        @extraction_forms_projects_section_type = ExtractionFormsProjectsSectionTypeWrapper.new "Results"
      else
        debugger
        #nothing
      end

      fixed_position = 1
      @questions.each do |q|
        q.set_position fixed_position
        fixed_position += 1
      end
    end

  end

  class SectionWrapper
    attr_accessor :name, :id
    @@id_counter = 1
    def initialize name
      @id = @@id_counter
      @@id_counter+=1
      @name = name
    end
  end

  class OrderingWrapper
    attr_accessor :id, :position
    @@id_counter = 1
    def initialize position
      @position = position
      @id = @@id_counter
      @@id_counter += 1
    end
  end

  class ExtractionFormsProjectsSectionTypeWrapper
    attr_accessor :name, :id
    def initialize name
      @name = name
      case name
      when "Type 1"
      @id = 1
      when "Type 2"
      @id = 2
      when "Results"
      @id = 3
      else
        debugger
      end
    end
  end

  class ExtractionFormsProjectsSectionOptionWrapper
    #does this ever get used
    @@id_counter = 1
    def initialize type
      @id = @@id_counter
      @by_type1 = false
      @include_total = false
    end

    def by_type1; @by_type1 end
    def include_total; @include_total end
    def id; @id end
  end

  class ExtractionFormsProjectsSectionsType1Wrapper
    @@id_counter = 1
    def initialize(name, description)
      @id = @@id_counter
      @@id_counter += 1
      @type1 = Type1Wrapper.new(name, description)
      #TODO: Identify Type1Type
      @type1_type = Type1TypeWrapper.new ""
    end

    def id; @id end
    def type1; @type1 end
    def type1_type; @type1_type end
  end

  class Type1Wrapper
    @@id_dict = {}
    @@id_counter = 1
    def initialize(name, description)
      if @@id_dict[name + "-----" + description]
        @id = @@id_dict[name + "-----" + description]
      else
        @id = @@id_counter
        @@id_dict[name + "-----" + description] = @id
        @@id_counter += 1
      end
      @name = name
      @description = description
    end

    def id; @id end
    def name; @name end
    def description; @description end
    def self.get_t1_id(name,description); @@id_dict[name + "-----" + description] end
  end

  class QuestionWrapper
    attr_accessor :id, :name, :description, :ordering, :key_questions_projects, :dependencies, :question_rows, :subquestions
    @@id_counter = 1
    @@id_dict = {
      "QualityDetail" => {},
      "ArmDetail" => {},
      "OutcomeDetail" => {},
      "BaselineCharacteristic" => {},
      "DesignDetail" => {},
      "DiagnosticTestDetail" => {},
      "AdverseEventColumn" => {}
    }

    def initialize q
      @dependencies = []
      @subquestions = []
      @question_rows = []
      @ordering = nil
      @key_questions_projects = []

      if q.class.name == "String"
        @id = @@id_counter
        @@id_counter += 1
        @name = q
        @description = ""
        #this is a subquestion
        return
      end

      @name = q.question
      @description = q.instruction

      if @@id_dict[q.class.name][q.id]
        @id = @@id_dict[q.class.name][q.id]
      else
        @id = @@id_counter
        @@id_dict[q.class.name][q.id] = @id
        @@id_counter += 1
      end

      ExtractionForm.find(q.extraction_form_id).extraction_form_key_questions.each do |efkq|
        kq = KeyQuestion.find(efkq.key_question_id)
        @key_questions_projects << KeyQuestionsProjectWrapper.new(kq)
      end

      field_model = nil
      dp_model = nil
      q_column = ""
      field_column = ""
      linked_t1_column = ""

      case q.class.name
      when "QualityDetail"
        field_model = QualityDetailField
        dp_model = QualityDetailDataPoint
        q_column = "quality_detail_id"
        field_column = "quality_detail_field_id"
        linked_t1_column = "outcome_id"
      when "ArmDetail"
        field_model = ArmDetailField
        dp_model = ArmDetailDataPoint
        q_column = "arm_detail_id"
        field_column = "arm_detail_field_id"
        linked_t1_column = "arm_id"
      when "DiagnosticTestDetail"
        field_model = DiagnosticTestDetailField
        dp_model = DiagnosticTestDetailDataPoint
        q_column = "diagnostic_test_detail_id"
        field_column = "diagnostic_test_detail_field_id"
        linked_t1_column = "diagnostic_test_id"
      when "OutcomeDetail"
        field_model = OutcomeDetailField
        dp_model = OutcomeDetailDataPoint
        q_column = "outcome_detail_id"
        field_column = "outcome_detail_field_id"
        linked_t1_column = "outcome_id"
      when "BaselineCharacteristic"
        field_model = BaselineCharacteristicField
        dp_model = BaselineCharacteristicDataPoint
        q_column = "baseline_characteristic_id"
        field_column = "baseline_characteristic_field_id"
        linked_t1_column = "diagnostic_test_id"
      when "DesignDetail"
        field_model = DesignDetailField
        dp_model = DesignDetailDataPoint
        q_column = "design_detail_id"
        field_column = "design_detail_field_id"
      #when "AdverseEvent"
        # TODO
        # ADVERSE EVENTS ARE WEIRD
        #field_model = AdverseEventField
        #q_column = "adverse_event_id"
      end

      case q.field_type
      when "text"
        qr = QuestionRowWrapper.new("")
        qrc = QuestionRowColumnWrapper.new("","text") ## set type inside qrc
        qrcf = QuestionRowColumnFieldWrapper.new
        qrc.question_row_column_fields << qrcf
        qr.question_row_columns << qrc
        @question_rows << qr

        dp_model.where(field_column => q.id).each do |dp|
          qrc.data_points << DataPointWrapper.new(dp)
        end

      when "checkbox"
        farr = field_model.where(q_column => q.id).order(row_number: :asc)
        qr = QuestionRowWrapper.new("")
        qrc = QuestionRowColumnWrapper.new("","checkbox") ## set type inside qrc
        qrcf = QuestionRowColumnFieldWrapper.new
        qrc.question_row_column_fields << qrcf
        qr.question_row_columns << qrc
        @question_rows << qr

        answer_dict = {}
        sq_dict = {}

        farr.each do |f|
          if f.row_number == -1
            qr = QuestionRowWrapper.new("Other: ")
            qrc = QuestionRowColumnWrapper.new("","text") ## set type inside qrc
            qrcf = QuestionRowColumnFieldWrapper.new
            qrc.question_row_column_fields << qrcf
            qr.question_row_columns << qrc
            @question_rows << other_qr


          #TODO: WHERE IS THE EXTRACTION ASSOCIATION, DUMMY
            dp = dp_model.where(field_column => f.id).first
            if dp then qrc.data_points << DataPointWrapper.new(dp) end

            next
          end

          option_id = qrc.add_answer_choice(f.option_text)
          answer_dict[f.option_text] = option_id.to_s

          if f.has_subquestion
            ## how to add subquestion to extraction_form??
            sq = QuestionWrapper.new(f.option_text + "..." + f.subquestion)
            sq.key_questions_projects = @key_questions_projects
            sq.dependencies << DependencyWrapper.new("QuestionRowColumnsQuestionRowColumnOption", option_id)
            sqr = QuestionRowWrapper.new("")
            sqrc = QuestionRowColumnWrapper.new("", "text")
            sqrcf = QuestionRowColumnFieldWrapper.new
            sqrc.question_row_column_fields << sqrcf
            sqr.question_row_columns << sqrc
            sq.question_rows << sqr
            sq_dict[f.option_text] = sqrc
            @subquestions << sq
          end
        end

        dpdict = {}
        dp_model.where(field_column => q.id).each do |dp|
          if dp.subquestion_value.present?
            sq_dict[dp.value].data_points << DataPointWrapper.new(dp, dp.subquestion_value)
          end
          if linked_t1_column.present?
            dpdict[dp.public_send(linked_t1_column)] ||= []
            dpdict[dp.public_send(linked_t1_column)] << dp
          else 
            dpdict["no_linked_t1"] ||= []
            dpdict["no_linked_t1"] << dp
          end
        end

        dpdict.each do |t1_id, dparr|
          ridarr = dparr.map{|dp| answer_dict[dp.value]}
          qrc.data_points << DataPointWrapper.new(dparr.first,"[" + ridarr.join(", ") + "]")
        end

      when "radio"
        farr = field_model.where(q_column => q.id).order(row_number: :asc)
        qr = QuestionRowWrapper.new("")
        qrc = QuestionRowColumnWrapper.new("","radio") ## set type inside qrc
        qrcf = QuestionRowColumnFieldWrapper.new
        qrc.question_row_column_fields << qrcf
        qr.question_row_columns << qrc
        @question_rows << qr

        answer_dict = {}
        sq_dict = {}

        farr.each do |f|
          if f.row_number == -1
            qr = QuestionRowWrapper.new("Other: ")
            qrc = QuestionRowColumnWrapper.new("","text") ## set type inside qrc
            qrcf = QuestionRowColumnFieldWrapper.new
            qrc.question_row_column_fields << qrcf
            qr.question_row_columns << qrc
            @question_rows << other_qr

            dp_model.where(field_column => f.id).each do |dp|
              if dp then qrc.data_points << DataPointWrapper.new(dp) end
            end
            next
          end

          option_id = qrc.add_answer_choice(f.option_text)
          answer_dict[f.option_text] = option_id.to_s

          if f.has_subquestion
            sq = QuestionWrapper.new(f.option_text + "..." + f.subquestion)
            sq.key_questions_projects = @key_questions_projects
            sq.dependencies << DependencyWrapper.new("QuestionRowColumnsQuestionRowColumnOption", option_id)
            sqr = QuestionRowWrapper.new("")
            sqrc = QuestionRowColumnWrapper.new("", "text")
            sqrcf = QuestionRowColumnFieldWrapper.new
            sqrc.question_row_column_fields << sqrcf
            sqr.question_row_columns << sqrc
            sq.question_rows << sqr
            sq_dict[f.option_text] = sqrc
            @subquestions << sq
          end
        end

          #TODO: WHERE IS THE EXTRACTION ASSOCIATION, DUMMY
        dp_model.where(field_column => q.id).each do |dp|
          if dp.subquestion_value.present?
            begin
              sq_dict[dp.value].data_points << DataPointWrapper.new(dp, dp.subquestion_value)
            rescue 
              debugger
            end
          end

          if answer_dict[dp.value].nil?
            debugger
          end
          qrc.data_points << DataPointWrapper.new(dp, answer_dict[dp.value])
        end

      when "select"
        farr = field_model.where(q_column => q.id).order(row_number: :asc)
        qr = QuestionRowWrapper.new("")
        qrc = QuestionRowColumnWrapper.new("","dropdown") ## set type inside qrc
        qrcf = QuestionRowColumnFieldWrapper.new
        qrc.question_row_column_fields << qrcf
        qr.question_row_columns << qrc
        @question_rows << qr
        answer_dict = {}

        sq_dict = {}

        farr.each do |f|
          if f.row_number == -1
            qr = QuestionRowWrapper.new("Other: ")
            qrc = QuestionRowColumnWrapper.new("","text") ## set type inside qrc
            qrcf = QuestionRowColumnFieldWrapper.new
            qrc.question_row_column_fields << qrcf
            qr.question_row_columns << qrc
            @question_rows << qr

            dp_model.where(field_column => f.id).each do |dp|
              if dp then qrc.data_points << DataPointWrapper.new(dp) end
            end
            next
          end

          option_id = qrc.add_answer_choice(f.option_text)
          answer_dict[f.option_text] = option_id.to_s

          if f.has_subquestion
            sq = QuestionWrapper.new(f.option_text + "..." + f.subquestion)
            sq.key_questions_projects = @key_questions_projects
            sq.dependencies << DependencyWrapper.new("QuestionRowColumnsQuestionRowColumnOption", option_id)
            sqr = QuestionRowWrapper.new("")
            sqrc = QuestionRowColumnWrapper.new("", "text")
            sqrcf = QuestionRowColumnFieldWrapper.new
            sqrc.question_row_column_fields << sqrcf
            sqr.question_row_columns << sqrc
            sq.question_rows << sqr
            sq_dict[f.option_text] = sqrc
            @subquestions << sq
          end
        end

        dp_model.where(field_column => q.id).each do |dp|
          if dp.subquestion_value.present?
            begin
              sq_dict[dp.value].data_points << DataPointWrapper.new(dp, dp.subquestion_value)
            rescue
              debugger
            end
          end

          if answer_dict[dp.value].nil?
            debugger
          end
          qrc.data_points << DataPointWrapper.new(dp, answer_dict[dp.value])
        end
      when "matrix_checkbox"
        r_farr = field_model.where(q_column => q.id, :column_number => 0).order(row_number: :asc)
        c_farr = field_model.where(q_column => q.id, :row_number => 0).order(column_number: :asc)

        other_qr = nil

        r_farr.each do |rf|
          answer_dict = {}
          sq_dict = {}

          if rf.row_number == -1
            qr = QuestionRowWrapper.new("Other: ")
            qrc = QuestionRowColumnWrapper.new("","text") ## set type inside qrc
            qrcf = QuestionRowColumnFieldWrapper.new
            qrc.question_row_column_fields << qrcf
            qr.question_row_columns << qrc
            other_qr = qr

            dp_model.where(:row_field_id => rf.id).each do |dp|
              if dp then qrc.data_points << DataPointWrapper.new(dp) end
            end
            next
          end

          qr = QuestionRowWrapper.new(rf.option_text)
          qrc = QuestionRowColumnWrapper.new("","checkbox") ## set type inside qrc
          qrcf = QuestionRowColumnFieldWrapper.new
          qrc.question_row_column_fields << qrcf
          qr.question_row_columns << qrc
          @question_rows << qr

          c_farr.each do |cf|
            option_id = qrc.add_answer_choice(cf.option_text)
            answer_dict[cf.option_text] = option_id.to_s

            if cf.has_subquestion
              sq = QuestionWrapper.new(cf.option_text + "..." + cf.subquestion)
              sq.key_questions_projects = @key_questions_projects
              sq.dependencies << DependencyWrapper.new("QuestionRowColumnsQuestionRowColumnOption", option_id)
              sqr = QuestionRowWrapper.new("")
              sqrc = QuestionRowColumnWrapper.new("", "text")
              sqrcf = QuestionRowColumnFieldWrapper.new
              sqrc.question_row_column_fields << sqrcf
              sqr.question_row_columns << sqrc
              sq.question_rows << sqr
              sq_dict[f.id.to_s] = sqrc
              @subquestions << sq
            end
          end

          dpdict = {}
          dp_model.where(:row_field_id => rf.id).each do |dp|
            if dp.subquestion_value.present?
              sq_dict[dp.value].data_points << DataPointWrapper.new(dp, dp.subquestion_value)
            end
            if linked_t1_column.present?
              dpdict[dp.public_send(linked_t1_column)] ||= []
              dpdict[dp.public_send(linked_t1_column)] << dp
            else 
              dpdict["no_linked_t1"] ||= []
              dpdict["no_linked_t1"] << dp
            end
            end

          dpdict.each do |t1_id, dparr|
            ridarr = dparr.map{|dp| answer_dict[dp.value]}
            qrc.data_points << DataPointWrapper.new(dparr.first,"[" + ridarr.join(", ") + "]")
          end
        end

        if other_qr
          @question_rows << other_qr
          other_qr = nil
        end

      when "matrix_radio" 
        r_farr = field_model.where(q_column => q.id, :column_number => 0).order(row_number: :asc)
        c_farr = field_model.where(q_column => q.id, :row_number => 0).order(column_number: :asc)

        other_qr = nil

        answer_dict = {}
        sq_dict = {}

        r_farr.each do |rf|
          if rf.row_number == -1
            qr = QuestionRowWrapper.new("Other: ")
            qrc = QuestionRowColumnWrapper.new("","text") ## set type inside qrc
            qrcf = QuestionRowColumnFieldWrapper.new
            qrc.question_row_column_fields << qrcf
            qr.question_row_columns << qrc
            other_qr = qr

            dp_model.where(:row_field_id => rf.id).each do |dp|
              if dp then qrc.data_points << DataPointWrapper.new(dp) end
            end
            next
          end

          qr = QuestionRowWrapper.new(rf.option_text)
          qrc = QuestionRowColumnWrapper.new("","radio") ## set type inside qrc
          qrcf = QuestionRowColumnFieldWrapper.new
          qrc.question_row_column_fields << qrcf
          qr.question_row_columns << qrc
          @question_rows << qr

          c_farr.each do |cf|
            option_id = qrc.add_answer_choice(cf.option_text)
            answer_dict[cf.option_text] = option_id.to_s

            if cf.has_subquestion
              ## how to add subquestion to extraction_form??
              sq = QuestionWrapper.new(cf.option_text + "..." + cf.subquestion)
              sq.key_questions_projects = @key_questions_projects
              sq.dependencies << DependencyWrapper.new("QuestionRowColumnsQuestionRowColumnOption", option_id)
              sqr = QuestionRowWrapper.new("")
              sqrc = QuestionRowColumnWrapper.new("", "text")
              sqrcf = QuestionRowColumnFieldWrapper.new
              sqrc.question_row_column_fields << sqrcf
              sqr.question_row_columns << sqrc
              sq.question_rows << sqr
              sq_dict[f.id.to_s] = sqrc
              @subquestions << sq
            end
          end

          dp_model.where(:row_field_id => rf.id).each do |dp|
            if dp.subquestion_value.present?
              sq_dict[answer_dict[dp.value]].data_points << DataPointWrapper.new(dp, dp.subquestion_value)
            end

            if answer_dict[dp.value].nil?
              debugger
            end
            qrc.data_points << DataPointWrapper.new(dp, answer_dict[dp.value])
          end
        end

        if other_qr
          @question_rows << other_qr
          other_qr = nil
        end

      when "matrix_select"
        r_farr = field_model.where(q_column => q.id, :column_number => 0).order(row_number: :asc)
        c_farr = field_model.where(q_column => q.id, :row_number => 0).order(column_number: :asc)

        other_qr = nil

        r_farr.each do |rf|
          if rf.row_number == -1 
            qr = QuestionRowWrapper.new("Other: ")
            qrc = QuestionRowColumnWrapper.new("","text") ## set type inside qrc
            qrcf = QuestionRowColumnFieldWrapper.new
            qrc.question_row_column_fields << qrcf
            qr.question_row_columns << qrc
            other_qr = qr

            dp_model.where(:row_field_id => rf.id).each do |dp|
              if dp then qrc.data_points << DataPointWrapper.new(dp) end
            end
            next
          end

          qr = QuestionRowWrapper.new(rf.option_text)

          c_farr.each do |cf|
            answer_dict = {}
            sq = nil

            dropdown_options = []
            MatrixDropdownOption.where(row_id: rf.id, column_id: cf.id).each do |op|
              dropdown_options << op
            end

            qrc = nil
            if not dropdown_options.empty?
              qrc = QuestionRowColumnWrapper.new(cf.option_text,"dropdown") ## set type inside qrc
              dropdown_options.each do |op|
                option_id = qrc.add_answer_choice(op.option_text)
                answer_dict[op.option_text] = option_id.to_s
              end
            else
              qrc = QuestionRowColumnWrapper.new(cf.option_text,"text") ## set type inside qrc
            end

            qrcf = QuestionRowColumnFieldWrapper.new
            qrc.question_row_column_fields << qrcf
            qr.question_row_columns << qrc
            @question_rows << qr

            if q.include_other_as_option
              option_id = qrc.add_answer_choice("Other...")
              answer_dict["Other"] = option_id.to_s
              ## how to add subquestion to extraction_form??
              sq = QuestionWrapper.new(rf.option_text + "-" + cf.option_text + "...Other")
              sq.key_questions_projects = @key_questions_projects
              sq.dependencies << DependencyWrapper.new("QuestionRowColumnsQuestionRowColumnOption", option_id)
              sqr = QuestionRowWrapper.new("")
              sqrc = QuestionRowColumnWrapper.new("", "text")
              sqrcf = QuestionRowColumnFieldWrapper.new
              sqrc.question_row_column_fields << sqrcf
              sqr.question_row_columns << sqrc
              sq.question_rows << sqr
              @subquestions << sq
            end

            dp_model.where(:row_field_id => rf.id, :column_field_id => cf.id).each do |dp|
              if dropdown_options.empty?
                qrc.data_points << DataPointWrapper.new(dp)
              elsif answer_dict[dp.value].nil?
                qrc.data_points << DataPointWrapper.new(dp, answer_dict["Other..."])
                sqrc.data_points << DataPointWrapper.new(dp)
              else
                qrc.data_points << DataPointWrapper.new(dp, answer_dict[dp.value])
              end
            end
          end
        end

        if other_qr
          @question_rows << other_qr
          other_qr = nil
        end
      end
    end

    def set_position(new_position)
      @ordering = OrderingWrapper.new(new_position)
    end
    def self.get_q_id(q); @@id_dict[q.class.name][q.id] end
  end

  class DependencyWrapper
    attr_accessor :prerequisitable_id, :prerequisitable_type, :id
    @@id_counter = 1
    def initialize p_type, p_id
      @id = @@id_counter 
      @@id_counter += 1
      @prerequisitable_id = p_id
      @prerequisitable_type = p_type
    end
  end

  class QuestionRowWrapper
    attr_accessor :question_row_columns, :name, :id
    @@id_counter = 1
    def initialize name
      @id = @@id_counter
      @@id_counter += 1
      @name = name
      @question_row_columns = []
    end
  end

  class QuestionRowColumnWrapper
    attr_accessor :name, :id, :question_row_column_type, :question_row_column_fields, :question_row_columns_question_row_column_options, :data_points
    @@id_counter = 1
    def initialize name, type
      @id = @@id_counter
      @@id_counter += 1
      @name = name
      @question_row_column_type = QuestionRowColumnTypeWrapper.new type
      @data_points = []
      @question_row_column_fields = []

      @question_row_columns_question_row_column_options = []
      @question_row_columns_question_row_column_options << QuestionRowColumnsQuestionRowColumnOptionWrapper.new("min_length", nil)
      @question_row_columns_question_row_column_options << QuestionRowColumnsQuestionRowColumnOptionWrapper.new("max_length", nil)
      @question_row_columns_question_row_column_options << QuestionRowColumnsQuestionRowColumnOptionWrapper.new("additional_char", nil)
      @question_row_columns_question_row_column_options << QuestionRowColumnsQuestionRowColumnOptionWrapper.new("min_value", nil)
      @question_row_columns_question_row_column_options << QuestionRowColumnsQuestionRowColumnOptionWrapper.new("max_value", nil)
      @question_row_columns_question_row_column_options << QuestionRowColumnsQuestionRowColumnOptionWrapper.new("coefficient", nil)
      @question_row_columns_question_row_column_options << QuestionRowColumnsQuestionRowColumnOptionWrapper.new("exponent", nil)

      if type == "text"
        @question_row_columns_question_row_column_options << QuestionRowColumnsQuestionRowColumnOptionWrapper.new("answer_choice", nil)
      end
    end

    def add_answer_choice(option)
      qrcqrco = QuestionRowColumnsQuestionRowColumnOptionWrapper.new("answer_choice", option)
      @question_row_columns_question_row_column_options << qrcqrco
      return qrcqrco.id
    end
  end

  class QuestionRowColumnTypeWrapper
    attr_accessor :name, :id
    @@id_dict = { "text" => 1,
               "numeric" => 2,
               "numeric_range" => 3,
               "scientific" => 4,
               "checkbox" => 5,
               "dropdown" => 6,
               "radio" => 7,
               "select2_single" => 8,
               "select2_multi" => 9 }
    def initialize name
      @name = name
      @id = @@id_dict[name]
    end
  end

  class QuestionRowColumnsQuestionRowColumnOptionWrapper
    @@name_dict = { "answer_choice" => '',
               "min_length" => '0',
               "max_length" => '255',
               "additional_char" => '0',
               "min_value" => '0',
               "max_value" => '255',
               "coefficient" => '5',
               "exponent" => '0' }
    @@id_counter = 1
    attr_accessor :question_row_column_option, :id, :name
    def initialize qrco, name
      @id = @@id_counter
      @@id_counter += 1
      if name == nil
        @name = @@name_dict[qrco]
      else
        @name = name
      end
      @question_row_column_option = QuestionRowColumnOptionWrapper.new(qrco)
    end
  end

  class QuestionRowColumnOptionWrapper
    attr_accessor :name, :id
    @@id_dict = { "answer_choice" => 1,
               "min_length" => 2,
               "max_length" => 3,
               "additional_char" => 4,
               "min_value" => 5,
               "max_value" => 6,
               "coefficient" => 7,
               "exponent" => 8 }
    def initialize name
      @id = @@id_dict[name]
      @name = name
    end
  end

  class QuestionRowColumnFieldWrapper
    attr_accessor :name, :id
    @@id_counter = 1
    def initialize
      @id = @@id_counter
      @@id_counter += 1
      @name = ""
    end
  end

  class ExtractionWrapper
    attr_accessor :id, :citations_project, :projects_users_role, :extractions_extraction_forms_projects_sections
    @@id_count = 1
    @@id_dict = {}
    def initialize cp, pur, efp
      @id = @@id_count
      @@id_count += 1
      @citations_project = cp
      @projects_users_role = pur
      @extractions_extraction_forms_projects_sections = []

      @@id_dict[cp.id] = self

      eefps_name_dict = {}

      efp.extraction_forms_projects_sections.each do |efps|
        eefps = ExtractionsExtractionFormsProjectsSectionWrapper.new(self, efps)
        @extractions_extraction_forms_projects_sections << eefps
        eefps_name_dict[eefps.extraction_forms_projects_section.section.name] = eefps

        if eefps.extraction_forms_projects_section.link_to_type1
          eefps.link_to_type1 = eefps_name_dict[eefps.extraction_forms_projects_section.link_to_type1.section.name]
        end
      end
    end

    def create_total_arm
      self.extractions_extraction_forms_projects_sections.each do |eefps|
        if eefps.extraction_forms_projects_section.section.name == "Arms"
          debugger
          t1 = Type1Wrapper.new("Total", "")
          eefpst1 = ExtractionsExtractionFormsProjectsSectionsType1Wrapper.new(self, t1, nil, nil, "Arm", 0)
          eefps.extractions_extraction_forms_projects_sections_type1s << eefpst1
        end
      end
    end
    def self.find_extraction(study_id); @@id_dict[study_id] end
  end

  class ExtractionsExtractionFormsProjectsSectionsQuestionRowColumnFieldWrapper
    attr_accessor :question_row_column_field, :records, :extractions_extraction_forms_projects_sections_type1
    def initialize eefps, qrc
      @question_row_column_field = qrc.question_row_column_fields.first
      @records = []
      qrc.data_points.each do |dp|
        #@dp_extraction = ExtractionWrapper.find_extraction(dp.study_id)
        #TODO: this is not the only way to make this comparison, extraction should know its study_id
        #TODO: this is not the only way to make this comparison, extraction should know its study_id
        #TODO: this is not the only way to make this comparison, extraction should know its study_id
        #TODO: this is not the only way to make this comparison, extraction should know its study_id
        #TODO: this is not the only way to make this comparison, extraction should know its study_id

        dp_eefpst1 = ExtractionsExtractionFormsProjectsSectionsType1Wrapper.find_eefpst1 eefps.extraction.id, dp.t1_type, dp.t1_id
        if dp.study_id == eefps.extraction.citations_project.id
          @records << RecordWrapper.new(dp.name, dp_eefpst1)
        end
      end
    end
  end

  class RecordWrapper
    attr_accessor :id, :name, :extractions_extraction_forms_projects_sections_type1
    @@id_counter = 1
    def initialize(name, eefpst1)
      @id = @@id_counter
      @@id_counter += 1
      @name = name
      @extractions_extraction_forms_projects_sections_type1 = eefpst1
    end
  end

  class ExtractionsExtractionFormsProjectsSectionWrapper
    attr_accessor :id, :extraction, :extraction_forms_projects_section, :extractions_extraction_forms_projects_sections_type1s, :link_to_type1, :extractions_extraction_forms_projects_sections_question_row_column_fields
    @@id_count = 1
    @@id_dict = {}
    def initialize(ex, efps)
      @@id_dict[ex.id] ||= {}
      if @@id_dict[ex.id][efps.id]
        @id = @@id_dict[ex.id][efps.id]
      else
        @id = @@id_count
        @@id_count += 1
        @@id_dict[ex.id][efps.id] = @id
      end
      @extraction = ex
      @extraction_forms_projects_section = efps

      # @link_to_type1 = nil
      # if efps.link_to_type1
      #   if @@id_dict[ex.id][efps.link_to_type1]
      #     @link_to_type1 = @@id_dict[ex.id][efps.link_to_type1]
      #   else
      #     @@id_dict[ex.id][efps.link_to_type1] = @@id_count
      #     @link_to_type1 = @@id_dict[ex.id][efps.link_to_type1]
      #     @@id_count += 1
      #   end
      # end

      @data_points = []
      @extractions_extraction_forms_projects_sections_type1s = []
      @extractions_extraction_forms_projects_sections_question_row_column_fields = []

      #maybe we have a little dictionary here
      # @eefpst1_dict = {"Outcome" => {},"Arm" => {}, "Adverse Event" => {}, "Diagnostic Test" => {}}

      case efps.section.name
      when "Outcomes"
        Outcome.where(study_id: ex.citations_project.id).each do |outcome|
          t1 = Type1Wrapper.new(outcome.title, outcome.description) #ignoring notes? There is no column for this
          units = outcome.units || ""
          t1_type = nil
          if outcome.outcome_type
            t1_type = Type1TypeWrapper.new outcome.outcome_type
          end
         eefpst1 = ExtractionsExtractionFormsProjectsSectionsType1Wrapper.new(self, t1, units, t1_type, "Outcome", outcome.id)
         @extractions_extraction_forms_projects_sections_type1s << eefpst1
         # @eefpst1_dict[outcome.id] = eefpst1
         eefpst1.create_populations outcome.id
        end
      when "Adverse Events"
        AdverseEvent.where(study_id: ex.citations_project.id).each do |ae|
          t1 = Type1Wrapper.new(ae.title, ae.description) #ignoring notes? There is no column for this
          eefpst1 = ExtractionsExtractionFormsProjectsSectionsType1Wrapper.new(self, t1, nil, nil, "Adverse Event", ae.id)
          @extractions_extraction_forms_projects_sections_type1s << eefpst1
          # @eefpst1_dict[ae.id] = eefpst1
        end
      when "Arms"
        Arm.where(study_id: ex.citations_project.id).each do |arm|
          t1 = Type1Wrapper.new(arm.title, arm.description) #ignoring notes? There is no column for this
          eefpst1 = ExtractionsExtractionFormsProjectsSectionsType1Wrapper.new(self, t1, nil, nil, "Arm", arm.id)
          @extractions_extraction_forms_projects_sections_type1s << eefpst1
          # @eefpst1_dict[arm.id] = eefpst1
        end
      when "Diagnostic Tests"
        DiagnosticTest.where(study_id: ex.citations_project.id).each do |dt|
          t1 = Type1Wrapper.new(dt.title, dt.description) #ignoring notes? There is no column for this
          eefpst1 = ExtractionsExtractionFormsProjectsSectionsType1Wrapper.new(self, t1, nil, nil, "Diagnostic Test", dt.id)
          @extractions_extraction_forms_projects_sections_type1s << eefpst1
          # @eefpst1_dict[dt.id] = eefpst1
        end

      when "Arm Details", "Outcome Details", "Design Details", "Diagnostic Test Details" #TODO: Adverse Events, Quality Dimensions, Baseline Characteristics, Comparisons
        efps.questions.each do |q|
          q.question_rows.each do |qr|
            qr.question_row_columns.each do |qrc|
              qrcf = qrc.question_row_column_fields.first # Right?
              eefpsqrcf = ExtractionsExtractionFormsProjectsSectionsQuestionRowColumnFieldWrapper.new(self, qrc)
              @extractions_extraction_forms_projects_sections_question_row_column_fields << eefpsqrcf
            end
          end
        end
        #TODO: Think
      end
    end

    # def find_eefpst1 t1_type, t1_id; debugger; @eefpst1_dict[t1_type][t1_id] end
  end

  class ExtractionsExtractionFormsProjectsSectionsType1Wrapper
    attr_accessor :id, :type1, :extractions_extraction_forms_projects_section, :extractions_extraction_forms_projects_sections_type1_rows, :type1_type, :units
    @@id_dict = {}
    @@table_dict = {}
    @@id_count = 1
    def initialize(eefps, t1, units, t1_type, table_name, table_id)
      @@id_dict[eefps.id] ||= {}
      if @@id_dict[eefps.id][t1.id]
        @id = @@id_dict[eefps.id][t1.id]
      else
        @id = @@id_count
        @@id_count += 1
        @@id_dict[eefps.id][t1.id] = @id
      end
      @type1 = t1
      @extractions_extraction_forms_projects_section = eefps

      @@table_dict[eefps.extraction.id] ||= {"self" => eefps.extraction}
      @@table_dict[eefps.extraction.id][table_name] ||= {}
      @@table_dict[eefps.extraction.id][table_name][table_id] = self

      @extractions_extraction_forms_projects_sections_type1_rows = []

      @type1_type = t1_type
      @units = units || ""
    end

    def create_populations(outcome_id)
      OutcomeSubgroup.where(outcome_id: outcome_id).each do |os|
        @extractions_extraction_forms_projects_sections_type1_rows << ExtractionsExtractionFormsProjectsSectionsType1RowWrapper.new(self, os)
      end
    end

    def self.find_eefpst1(ex_id, table_name, table_id)
      if table_name = "Arm" and table_id == 0 and @@table_dict[ex_id][table_name][table_id].nil?
        debugger
        @@table_dict[ex_id]["self"].create_total_arm
      end
      @@table_dict[ex_id][table_name][table_id] 
    end
  end

  class ExtractionsExtractionFormsProjectsSectionsType1RowWrapper
    attr_accessor :id, :population_name, :result_statistic_sections, :extractions_extraction_forms_projects_sections_type1_row_columns
    def initialize eefpst1, os
      @eefpst1 = eefpst1
      @extraction = eefpst1.extractions_extraction_forms_projects_section.extraction
      @id = os.id
      @population_name = PopulationNameWrapper.new(os.title, os.description)
      @result_statistic_sections = [] #TODO THIS IS SUPPOSED TO BE COMPLICATED
      @extractions_extraction_forms_projects_sections_type1_row_columns = []

      @tp_dict = {}
      OutcomeTimepoint.where(outcome_id: os.outcome_id).each do |ot|
        eefpst1r = ExtractionsExtractionFormsProjectsSectionsType1RowColumnWrapper.new(ot)
        @extractions_extraction_forms_projects_sections_type1_row_columns << eefpt1r
        @tp_dict[ot.id] = eefpst1r
      end

      o = Outcome.find(os.outcome_id)
      ode_arr = OutcomeDataEntry.includes([:outcome_measures => :outcome_data_points]).where(outcome_id: o.id)
      bac_arr = Comparison.includes([{:comparison_measures => :comparison_data_points}, :comparators]).where(outcome_id: o.id, within_or_between: "between")
      wac_arr = Comparison.includes([{:comparison_measures => :comparison_data_points}, :comparators]).where(outcome_id: o.id, within_or_between: "within")

      #we need 4 rss
      ds_rss = ResultStatisticSectionWrapper.new("Descriptive Statistics")
      ode_arr.each do |ode|
        ode.outcome_measures.each do |om|
          rssm = ResultStatisticSectionsMeasureWrapper.new om.title
          tp = @tp_dict[ode.timepoint_id]

          om.outcome_data_points.each do |odp|
            record_name = odp.value
            arm_eefpst1 = ExtractionsExtractionFormsProjectsSectionsType1Wrapper.find_eefpst1(@extraction, 'Arm', odp.arm_id) 
            rssm.tps_arms_rssms << LoyloyWrapper.new 
          end
          ds_rss.result_statistic_section_measures << rssm
        end
      end
      bac_rss = ResultStatisticSectionWrapper.new("Between Arm Comparisons")
      bac_arr.each do |comparison|
        comparison.comparators.each do |comparator|
          case comparison.within_or_between
          when "within"
            tparr = comparator.comparator.split "_"
            tp_1 = @tp_dict[tparr.first]
            tp_2 = @tp_dict[tparr.second]
            bac_rss.comparisons << ComparisonWrapper.new(tp_1, tp_2)
          when "between"
            armarr = comparator.comparator.split "_"
            arm_1 = @tp_dict[tparr.first]
            arm_2 = @tp_dict[tparr.second]
            bac_rss.comparisons << ComparisonWrapper.new(arm_1, arm_2)
          end
        end
      end
      wac_rss = ResultStatisticSectionWrapper.new("Within Arm Comparisons")
      net_rss = ResultStatisticSectionWrapper.new("NET Change")
      @result_statistic_sections << ds_rss
      @result_statistic_sections << bac_rss
      @result_statistic_sections << wac_rss
      @result_statistic_sections << net_rss
    end

    def get_tp tpid; @tp_dict[tpid] end
  end

  class LoyloyWrapper ## GENERIC CLASS FOR HOLDING tps_arms_rssm, comparisons_arms_rssms, tps_comparisons_rssms, wacs_bacs_rssms
    attr_accessor :id, :comparison, :timepoint, :extractions_extraction_forms_projects_sections_type1, :wac, :bac, :record
    @@id_counter = 1
    def initialize tp, arm, comparison, wac, bac, record_name
      @id = @@id_counter
      @@id_counter += 1
      @timepoint = tp
      @extractions_extraction_forms_projects_sections_type1 = arm
      @record = ResultRecordWrapper.new record_name
      @wac = wac
      @bac = bac
    end
  end

  class ResultRecordWrapper
    attr_accessor :name, :id
    @@id_counter = 1
    def initialize name
      @id = @@id_counter
      @@id_counter += 1
      @name = name
    end
  end

  class ResultStatisticSectionWrapper
    attr_accessor :id, :result_statistic_section_type, :comparisons, :result_statistic_section_measures
    @@id_counter = 1
    def initialize rss_type, de_arr
      @id = @@id_counter
      @@id_counter += 1
      @result_statistic_section_measures = []
      @result_statistic_section_type = ResultStatisticSectionTypeWrapper.name rss_type
      @comparisons = []

      case rss_type
        when "Descriptive Statistics"

        when "Between Arm Comparisons"
        when "Within Arm Comparisons"
        when "NET Change"
          ##NOTHING
        end
    end

    def create_comparisons comp_arr
    end
  end

  class ResultStatisticSectionTypeWrapper
    attr_accessor :id, :name
    @@id_dict = {}
    @@id_counter = 1
    def initialize name
      @name = name
      if @@id_dict[name]
        @id = @@id_dict[name]
      else
        @id = @@id_counter
        @@id_counter += 1
        @@id_dict[name] = @id
      end
    end
  end

  class ResultStatisticSectionsMeasureWrapper
    attr_accessor :id, :measure, :tps_comparisons_rssms, :tps_arms_rssms, :comparisons_arms_rssms, :wacs_bacs_rssms
    @@id_counter = 1
    def initialize measure_name
      @id = @@id_counter
      @@id_counter += 1
      @measure = MeasureWrapper.new(measure_name)

      @tps_comparisons_rssms = []
      @tps_arms_rssms = []
      @comparisons_arms_rssms = []
      @wacs_bacs_rssms = []
    end
  end

  class MeasureWrapper
    attr_accessor :id, :name
    @@id_counter = 1
    @@id_dict = {}
    def initialize name
      if @@id_dict[name]
        @id = @@id_dict[name]
      else
        @id = @@id_counter
        @@id_counter += 1
        @@id_dict[name] = @id
      end
      @name = name
    end

  class ExtractionsExtractionFormsProjectsSectionsType1RowColumnWrapper
    attr_accessor :id, :timepoint_name
    def initialize ot
      @id = ot.id
      @timepoint_name = TimepointNameWrapper.new(ot.number, ot.time_unit)
    end
  end

  class TimepointNameWrapper
    attr_accessor :id, :name, :unit
    @@id_dict = {}
    @@id_counter = 1
    def initialize name, unit
      if @@id_dict[name]
        @id = @@id_dict[name]
      else
        @id = @@id_counter
        @@id_counter += 1
      end
      @name = name
      @unit = unit
    end
  end

  class PopulationNameWrapper
    attr_accessor :id, :name, :description
    @@id_dict = {}
    @@id_counter = 1
    def initialize name, description
      if @@id_dict[name]
        @id = @@id_dict[name]
      else
        @id = @@id_counter
        @@id_counter += 1
      end
      @name = name
      @description = description
    end
  end

  class Type1TypeWrapper
    attr_accessor :id, :name
    @@id_dict = { "Categorical" => 1,
                   "Continuous" => 2,
                   "Time to Event" => 3,
                   "Adverse Event" => 4 }
    def initialize name
      @name = name
      @id = @@id_dict[name]
    end
  end

  class DataPointWrapper
    attr_accessor :name, :study_id, :t1_id, :t1_type#, :outcome, :comparator, :diagnostic_detail
    def initialize(dp, name=nil)
      if name
        @name = name
      else
        @name = dp.value
      end
      @study_id = dp.study_id
      @user_id = Study.find(dp.study_id)
      @t1_type = ""
      @t1_id = nil
      if dp.respond_to? :arm_id
        @t1_id = dp.arm_id
        @t1_type = "Arm"
      elsif dp.respond_to? :outcome_id
        @t1_id = dp.outcome_id
        @t1_type = "Outcome"
      elsif dp.respond_to? :diagnostic_test_id
        @t1_id = dp.diagnostic_test_id
        @t1_type = "Diagnostic Test"
      end
      #case dp.class.name
      #when "ArmDetailDataPoint"
      #  @name = dp.value
      #  @extraction = ExtractionWrapper.get_extraction dp.study_id
      #  @arm = ArmWrapper.get_arm dp.arm_id
      #  @outcome = nil
      #when "DesignDetailDataPoint"
      #  @name = dp.value
      #  @extraction = ExtractionWrapper.get_extraction dp.study_id
      #  @arm = nil
      #  @outcome = nil
      #when "OutcomeDetailDataPoint"
      #  @name = dp.value
      #  @extraction = ExtractionWrapper.get_extraction dp.study_id
      #  @arm = nil
      #  @outcome = OutcomeWrapper.get_outcome dp.outcome_id      when "AdverseEventDataPoint"
      #when "QualityDimensionDataPoint" #???
      #  @name = dp.value
      #  @extraction = ExtractionWrapper.get_extraction dp.study_id
      #  @arm = nil
      #  @outcome = nil
      #when "BaselineCharacteristic" #???? DiagnosticDetail association
      #  @name = dp.value
      #  @extraction = ExtractionWrapper.get_extraction dp.study_id
      #  @arm = ArmWrapper.get_arm dp.arm_id
      #  @outcome = nil
      ##TODO: DO SOmething about comparison
      #else
      #end
    end
  end
end
