class KanbanStagePolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || @account_user.agent?
  end

  def show?
    @account_user.administrator? || @account_user.agent?
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def reorder?
    @account_user.administrator?
  end

  def board_data?
    @account_user.administrator? || @account_user.agent?
  end

  def stage_conversations?
    @account_user.administrator? || @account_user.agent?
  end
end
