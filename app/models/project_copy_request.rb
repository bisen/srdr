class ProjectCopyRequest < ActiveRecord::Base
  belongs_to :user
  validates :user_id, :project_id, presence: true

  def to_s
    if self.include_data == true 
      return "Extraction Forms Only"
    elsif self.include_studies == true 
      return "Extraction Forms & Study List"
    elsif self.include_forms == true
      return "Extraction Forms, Studies & Extracted Data"
    else
      return "--"
    end
  end

  def self.mark_completed(user_id, project_id, clone_id)
    ProjectCopyRequest.transaction do 
      entry = ProjectCopyRequest.find(:first, 
        :conditions => ["user_id = ? AND project_id = ? 
          AND clone_id = ?", user_id, project_id, nil])
      unless entry.nil?
        entry.clone_id = clone_id
        entry.save
      end
    end
  end
end