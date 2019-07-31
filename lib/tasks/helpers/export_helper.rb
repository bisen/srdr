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

  class ExtractionFormsProjectsSectionOptionWrapper
    attr_accessor :id, :by_type1, :include_total
    @@id_counter = 1
    def initialize(by_t1, total)
      @id = @@id_counter
      @@id_counter += 1
      @by_type1 = by_t1 || false
      @include_total = total || false
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

      ef.extraction_form_sections.where( included: true, section_name: ["adverse","arm_details","arms","baselines","diagnostic_test_details", "diagnostic_tests", "design","outcome_details","outcomes","quality","results"] ).each do |s|
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
        when "quality", "arm_details","outcome_details", "quality_details", "diagnostic_test_details","design"
          @t2_efps << efps
        else
          @other_efps << efps
        end
      end

      @t2_efps.each do |efps|
        case efps.efs.section_name
        when "arm_details"
          efso = EfSectionOption.where(extraction_form_id: ef.id, section: "arm_detail").first
          if efso.by_arm
            efps.link_to_type1 = arms_efps
            efps.extraction_forms_projects_section_option = ExtractionFormsProjectsSectionOptionWrapper.new true, efso.include_total
          else
            efps.extraction_forms_projects_section_option = ExtractionFormsProjectsSectionOptionWrapper.new false, efso.include_total
          end
        when "outcome_details"
          efso = EfSectionOption.where(extraction_form_id: ef.id, section: "outcome_detail").first
          if efso.by_outcome
            efps.link_to_type1 = outcomes_efps
            efps.extraction_forms_projects_section_option = ExtractionFormsProjectsSectionOptionWrapper.new true, efso.include_total
          else
            efps.extraction_forms_projects_section_option = ExtractionFormsProjectsSectionOptionWrapper.new false, efso.include_total
          end
        when "diagnostic_test_details"
          efso = EfSectionOption.where(extraction_form_id: ef.id, section: "diagnostic_test").first
          if efso.by_diagnostic_test
            efps.link_to_type1 = diagnostic_tests_efps
            efps.extraction_forms_projects_section_option = ExtractionFormsProjectsSectionOptionWrapper.new true, efso.include_total
          else
            efps.extraction_forms_projects_section_option = ExtractionFormsProjectsSectionOptionWrapper.new false, efso.include_total
          end

        when "design", "quality"
          efps.extraction_forms_projects_section_option = ExtractionFormsProjectsSectionOptionWrapper.new false, false
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
      @extraction_forms_projects_section_option = nil
      @link_to_type1 = nil## TODO: link to right section
      @questions = []
      case efs.section_name
      when "adverse"
        @section = SectionWrapper.new "Adverse Events"
        @extraction_forms_projects_section_type = ExtractionFormsProjectsSectionTypeWrapper.new "Type 2"
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

      #TODO: THIS DOES NOT WORK
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
        QualityDimensionField.where( extraction_form_id: efs.extraction_form.id ).each do |qdf|
          @questions << QuestionWrapper.new(qdf)
        end

        QualityRatingField.where( extraction_form_id: efs.extraction_form.id ).each do |qrf|
          @questions << QuestionWrapper.new(qrf)
          break
        end

      #### This stuff is deprecated
      #  QualityDetail.where( extraction_form_id: efs.extraction_form.id ).each do |qd|
      #    question = QuestionWrapper.new(qd)
      #    @questions << question
      #    question.subquestions.each do |sq|
      #      @questions << sq
      #    end
      #  end
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
      if @@id_dict[(name || "") + "-----" + (description || "")]
        @id = @@id_dict[(name || "") + "-----" + (description || "")]
      else
        @id = @@id_counter
        @@id_dict[(name || "") + "-----" + (description || "")] = @id
        @@id_counter += 1
      end
      @name = name
      @description = description
    end

    def id; @id end
    def name; @name end
    def description; @description end
    def self.get_t1_id(name,description); @@id_dict[(name || "") + "-----" + (description || "")] end
  end

  class QuestionWrapper
    attr_accessor :id, :name, :description, :ordering, :key_questions_projects, :dependencies, :question_rows, :subquestions
    @@id_counter = 1
    @@id_dict = {
      "QualityDimensionField" => {},
      "QualityRatingField" => {},
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
        @name = q
        @description = ""
        @id = @@id_counter
        @@id_counter += 1
        #this is a subquestion
        return
      end

      if @@id_dict[q.class.name][q.id]
        @id = @@id_dict[q.class.name][q.id]
      else
        @id = @@id_counter
        @@id_dict[q.class.name][q.id] = @id
        @@id_counter += 1
      end

      case q.class.name
      when "QualityRatingField"
        initialize_as_quality_rating q
        return
      when "QualityDimensionField"
        initialize_as_quality_dimension q
        return
      end

      @name = q.question
      @description = q.instruction

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


            dp = dp_model.where(field_column => f.id).first
            if dp then qrc.data_points << DataPointWrapper.new(dp) end

            next
          end

          option_id = qrc.add_answer_choice(f.option_text)
          answer_dict[f.option_text] = option_id.to_s

          if f.has_subquestion
            ## how to add subquestion to extraction_form??
            sq = QuestionWrapper.new((f.option_text || "") + "..." + (f.subquestion || ""))
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
            sq = QuestionWrapper.new((f.option_text || "") + "..." + (f.subquestion || ""))
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
            sq_dict[dp.value].data_points << DataPointWrapper.new(dp, dp.subquestion_value)
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
            sq = QuestionWrapper.new((f.option_text || "") + "..." + (f.subquestion || ""))
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
            sq_dict[dp.value].data_points << DataPointWrapper.new(dp, dp.subquestion_value)
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
              sq = QuestionWrapper.new((f.option_text || "") + "..." + (f.subquestion || ""))
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
              sq = QuestionWrapper.new((f.option_text || "") + "..." + (f.subquestion || ""))
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
            answer_dict = {"" => ""}
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
              answer_dict["<<<Other...>>>"] = option_id.to_s
              ## how to add subquestion to extraction_form??
              sq = QuestionWrapper.new((rf.option_text || "") + "-" + (cf.option_text || "") + "...Other")
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
              # if no options, then we have a cell that is just a textbox
              if dropdown_options.empty?
                qrc.data_points << DataPointWrapper.new(dp)
              elsif answer_dict[dp.value].nil?
                qrc.data_points << DataPointWrapper.new(dp, answer_dict["<<<Other...>>>"])
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

    def initialize_as_quality_dimension(qdf)
      ef_id = qdf.extraction_form_id

      options_arr = QualityDimensionField.get_dropdown_options qdf.id

      qdf.title =~ /(.*) \[(.*)\]$/
      @name = $1 || qdf.title
      @description = qdf.field_notes
      @dependencies = []
      @subquestions = []
      @question_rows = []
      @key_questions_projects = []

      ExtractionForm.find(ef_id).extraction_form_key_questions.each do |efkq|
        kq = KeyQuestion.find(efkq.key_question_id)
        @key_questions_projects << KeyQuestionsProjectWrapper.new(kq)
      end

      # there are two rows in quality rating: 1) value
      #                                       2) notes

      #VALUE
      qr = QuestionRowWrapper.new("Value:")
      value_qrc = QuestionRowColumnWrapper.new("","dropdown") ## set type inside qrc
      qrcf = QuestionRowColumnFieldWrapper.new
      value_qrc.question_row_column_fields << qrcf
      qr.question_row_columns << value_qrc
      @question_rows << qr

      #NOTES
      qr = QuestionRowWrapper.new("Notes:")
      notes_qrc = QuestionRowColumnWrapper.new("","text") ## set type inside qrc
      qrcf = QuestionRowColumnFieldWrapper.new
      notes_qrc.question_row_column_fields << qrcf
      qr.question_row_columns << notes_qrc
      @question_rows << qr

      answer_dict = {}
      options_arr.each do |o|
        option_id = value_qrc.add_answer_choice(o[0])
        answer_dict[o[0]] = option_id.to_s
      end

      QualityDimensionDataPoint.where(extraction_form_id: ef_id, quality_dimension_field_id: qdf.id).each do |dp|
        notes_qrc.data_points << DataPointWrapper.new(dp, dp.notes)
        value_qrc.data_points << DataPointWrapper.new(dp, answer_dict[dp.value])
      end
    end

    def initialize_as_quality_rating(qrf)
      ef_id = qrf.extraction_form_id
      @name = "Adjust Quality Rating"
      @description = ""
      @dependencies = []
      @subquestions = []
      @question_rows = []
      @key_questions_projects = []

      ExtractionForm.find(ef_id).extraction_form_key_questions.each do |efkq|
        kq = KeyQuestion.find(efkq.key_question_id)
        @key_questions_projects << KeyQuestionsProjectWrapper.new(kq)
      end

      # there are three rows in quality rating: 1) guideline used
      #                                         2) overall rating
      #                                         3) notes

      #GUIDELINE USED
      qr = QuestionRowWrapper.new("Quality Guideline Used:")
      guideline_qrc = QuestionRowColumnWrapper.new("","text") ## set type inside qrc
      qrcf = QuestionRowColumnFieldWrapper.new
      guideline_qrc.question_row_column_fields << qrcf
      qr.question_row_columns << guideline_qrc
      @question_rows << qr

      #OVERALL RATING
      qr = QuestionRowWrapper.new("Select Current Overall Rating:")
      rating_qrc = QuestionRowColumnWrapper.new("","dropdown") ## set type inside qrc
      qrcf = QuestionRowColumnFieldWrapper.new
      rating_qrc.question_row_column_fields << qrcf
      qr.question_row_columns << rating_qrc
      @question_rows << qr

      #NOTES
      qr = QuestionRowWrapper.new("Notes on this Rating:")
      notes_qrc = QuestionRowColumnWrapper.new("","text") ## set type inside qrc
      qrcf = QuestionRowColumnFieldWrapper.new
      notes_qrc.question_row_column_fields << qrcf
      qr.question_row_columns << notes_qrc
      @question_rows << qr

      answer_dict = {}
      QualityRatingField.where(extraction_form_id: ef_id).order(display_number: :asc).each do |qrf|
        option_id = rating_qrc.add_answer_choice(qrf.rating_item)
        answer_dict[qrf.rating_item] = option_id.to_s
      end

      QualityRatingDataPoint.where(extraction_form_id: ef_id).each do |dp|
        guideline_qrc.data_points << DataPointWrapper.new(dp, dp.guideline_used)
        rating_qrc.data_points << DataPointWrapper.new(dp, answer_dict[dp.current_overall_rating])
        notes_qrc.data_points << DataPointWrapper.new(dp, dp.notes)
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
          t1 = Type1Wrapper.new("Total", "including all interventions")
          eefpst1 = ExtractionsExtractionFormsProjectsSectionsType1Wrapper.new(eefps, t1, nil, nil, "Arm", 0)
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

      when "Arm Details", "Outcome Details", "Design Details", "Diagnostic Test Details", "Quality", "Baseline Data"  #TODO: Adverse Events
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
      @@table_dict[ex_id] ||= {}
      @@table_dict[ex_id][table_name] ||= {}
      if table_name == "Arm" and table_id == 0 and @@table_dict[ex_id][table_name][table_id].nil?
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
        eefpst1rc = ExtractionsExtractionFormsProjectsSectionsType1RowColumnWrapper.new(ot)
        @extractions_extraction_forms_projects_sections_type1_row_columns << eefpst1rc
        @tp_dict[ot.id] = eefpst1rc
      end

      o = Outcome.find(os.outcome_id)
      ode_arr = OutcomeDataEntry.includes([:outcome_measures => :outcome_data_points]).where(outcome_id: o.id, subgroup_id: os.id)
      bac_arr = Comparison.includes([{:comparison_measures => :comparison_data_points}, :comparators]).where(outcome_id: o.id, within_or_between: "between", subgroup_id: os.id)
      wac_arr = Comparison.includes([{:comparison_measures => :comparison_data_points}, :comparators]).where(outcome_id: o.id, within_or_between: "within", subgroup_id: os.id)

      #tps_arms_rssms
      ds_rss = ResultStatisticSectionWrapper.new("Descriptive Statistics")
      ode_arr.each do |ode|
        ode.outcome_measures.each do |om|
          rssm = ResultStatisticSectionsMeasureWrapper.new om.title
          tp = @tp_dict[ode.timepoint_id]

          om.outcome_data_points.each do |odp|
            record_name = odp.value
            arm_eefpst1 = ExtractionsExtractionFormsProjectsSectionsType1Wrapper.find_eefpst1(@extraction.id, 'Arm', odp.arm_id) 
            rssm.tps_arms_rssms << LoyloyWrapper.new(tp, arm_eefpst1, nil, odp.value)
          end
          ds_rss.result_statistic_sections_measures << rssm
        end
      end

      #comparisons_arms_rssms
      wac_rss = ResultStatisticSectionWrapper.new("Within Arm Comparisons")
      wac_arr.each do |comparison|
        comp_dict = {}
        comparison.comparators.each do |comparator|
          if comparator.comparator != nil and comparator.comparator != ""
            if comparator.comparator == "000"
              new_comp =  ComparisonWrapper.new( true )
              wac_rss.comparisons << new_comp
              comp_dict[comparator.id] = new_comp
            else
              tparr = comparator.comparator.split "_"
              tp_1 = @tp_dict[tparr.first.to_i]
              tp_2 = @tp_dict[tparr.second.to_i]

              new_comp =  ComparisonWrapper.new( false )
              if tp_1.present? then new_comp.add_comparate tp_1 end
              if tp_2.present? then new_comp.add_comparate tp_2 end
              wac_rss.comparisons << new_comp
              comp_dict[comparator.id] = new_comp
            end
          else
            new_comp =  ComparisonWrapper.new( false )
            wac_rss.comparisons << new_comp
            comp_dict[comparator.id] = new_comp
          end
        end

        comparison.comparison_measures.each do |cm|
          rssm = ResultStatisticSectionsMeasureWrapper.new cm.title
          cm.comparison_data_points.each do |cdp|
            comp = comp_dict[cdp.comparator.id]
            record_name = cdp.value
            arm_eefpst1 = ExtractionsExtractionFormsProjectsSectionsType1Wrapper.find_eefpst1(@extraction.id, 'Arm', cdp.arm_id) 
            rssm.comparisons_arms_rssms << LoyloyWrapper.new(nil, arm_eefpst1, comp, cdp.value)
          end
          wac_rss.result_statistic_sections_measures << rssm
        end
      end

      #tps_comparisons_rssms
      bac_rss = ResultStatisticSectionWrapper.new("Between Arm Comparisons")
      bac_arr.each do |comparison|
        comp_dict = {}

        comparison.comparators.each do |comparator|
          if comparator.comparator != nil and comparator.comparator != ""
            if comparator.comparator == "000"
              new_comp =  ComparisonWrapper.new( true )
              bac_rss.comparisons << new_comp
              comp_dict[comparator.id] = new_comp
            else
              armarr = comparator.comparator.split "_"
              arm_1 = ExtractionsExtractionFormsProjectsSectionsType1Wrapper.find_eefpst1(@extraction.id, "Arm", armarr.first.to_i)
              arm_2 = ExtractionsExtractionFormsProjectsSectionsType1Wrapper.find_eefpst1(@extraction.id, "Arm", armarr.second.to_i)
              new_comp =  ComparisonWrapper.new( false )
              if arm_1.present? then new_comp.add_comparate arm_1 end
              if arm_2.present? then new_comp.add_comparate arm_2 end
              bac_rss.comparisons << new_comp
              comp_dict[comparator.id] = new_comp
            end
          else
            new_comp =  ComparisonWrapper.new( false )
            bac_rss.comparisons << new_comp
            comp_dict[comparator.id] = new_comp
          end
        end

        comparison.comparison_measures.each do |cm|
          rssm = ResultStatisticSectionsMeasureWrapper.new cm.title
          cm.comparison_data_points.each do |cdp|
            comp = comp_dict[cdp.comparator.id]
            record_name = cdp.value
            tp = @tp_dict[comparison.group_id]
            rssm.tps_comparisons_rssms << LoyloyWrapper.new(tp, nil, comp, cdp.value)
          end
          bac_rss.result_statistic_sections_measures << rssm
        end
      end

      net_rss = ResultStatisticSectionWrapper.new("NET Change")
      @result_statistic_sections << ds_rss
      @result_statistic_sections << bac_rss
      @result_statistic_sections << wac_rss
      @result_statistic_sections << net_rss
    end

    def get_tp tpid; @tp_dict[tpid] end
  end

  class LoyloyWrapper ## generic class for holding tps_arms_rssm, comparisons_arms_rssms, tps_comparisons_rssms, wacs_bacs_rssms
    attr_accessor :id, :comparison, :timepoint, :extractions_extraction_forms_projects_sections_type1, :records
    @@id_counter = 1
    def initialize tp, arm, comparison, record_name
      @id = @@id_counter
      @@id_counter += 1
      @timepoint = tp
      @comparison = comparison
      @extractions_extraction_forms_projects_sections_type1 = arm

      @records = [ RecordWrapper.new(record_name, nil) ]
    end
  end

  class ResultStatisticSectionWrapper
    attr_accessor :id, :result_statistic_section_type, :comparisons, :result_statistic_sections_measures
    @@id_counter = 1
    def initialize rss_type
      @id = @@id_counter
      @@id_counter += 1
      @result_statistic_sections_measures = []
      @result_statistic_section_type = ResultStatisticSectionTypeWrapper.new rss_type
      @comparisons = []
    end
  end

  class ComparisonWrapper
    attr_accessor :id, :comparate_groups, :is_anova
    @@id_counter = 1
    def initialize is_anova
      @is_anova = is_anova
      @id = @@id_counter
      @@id_counter += 1
      @comparate_groups = []
    end

    def add_comparate item
      @comparate_groups << ComparateGroupWrapper.new(item)
    end
  end

  class ComparateGroupWrapper
    attr_accessor :id, :comparates
    @@id_counter = 1
    def initialize item
      @id = @@id_counter
      @@id_counter += 1
      @comparates= []
      @comparates << ComparateWrapper.new(item)
    end
  end

  class ComparateWrapper
    attr_accessor :id, :comparable_element
    @@id_counter = 1
    def initialize item
      @id = @@id_counter
      @@id_counter += 1
      @comparable_element = ComparableElementWrapper.new(item)
    end
  end

  class ComparableElementWrapper
    attr_accessor :id, :comparable_type, :comparable_id
    @@id_counter = 1
    def initialize item
      @id = @@id_counter
      @@id_counter += 1
      case item.class.name
      when "ExportHelper::ExtractionsExtractionFormsProjectsSectionsType1RowColumnWrapper"
        @comparable_type = "ExtractionsExtractionFormsProjectsSectionsType1RowColumn"
      when "ExportHelper::ExtractionsExtractionFormsProjectsSectionsType1Wrapper"
        @comparable_type = "ExtractionsExtractionFormsProjectsSectionsType1"
      end
      @comparable_id = item.id
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
      case dp.class.name
      when "ArmDetailDataPoint"
        @t1_id = dp.arm_id
        @t1_type = if @t1_id.present? then "Arm" else nil end
      when "OutcomeDetailDataPoint"
        @t1_id = dp.outcome_id
        @t1_type = if @t1_id.present? then "Outcome" else nil end
      when "DiagnosticTestDetailDataPoint"
        @t1_id = dp.diagnostic_test_id
        @t1_type = if @t1_id.present? then "Diagnostic Test" else nil end
      when "DesignDetailDataPoint"
      when "QualityDimensionDataPoint"
      when "QualityRatingDataPoint"
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
