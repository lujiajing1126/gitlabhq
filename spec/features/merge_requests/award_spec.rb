require 'rails_helper'

feature 'Merge request awards', js: true, feature: true do
  let(:user) { create(:user) }
  let(:project) { create(:project, :public) }
  let(:merge_request) { create(:merge_request, source_project: project) }

  describe 'logged in' do
    before do
      gitlab_sign_in(user)
      visit project_merge_request_path(project, merge_request)
    end

    it 'adds award to merge request' do
      first('.js-emoji-btn').click
      expect(page).to have_selector('.js-emoji-btn.active')
      expect(first('.js-emoji-btn')).to have_content '1'

      visit project_merge_request_path(project, merge_request)
      expect(first('.js-emoji-btn')).to have_content '1'
    end

    it 'removes award from merge request' do
      first('.js-emoji-btn').click
      find('.js-emoji-btn.active').click
      expect(first('.js-emoji-btn')).to have_content '0'

      visit project_merge_request_path(project, merge_request)
      expect(first('.js-emoji-btn')).to have_content '0'
    end

    it 'has only one menu on the page' do
      first('.js-add-award').click
      expect(page).to have_selector('.emoji-menu')

      expect(page).to have_selector('.emoji-menu', count: 1)
    end
  end

  describe 'logged out' do
    before do
      visit project_merge_request_path(project, merge_request)
    end

    it 'does not see award menu button' do
      expect(page).not_to have_selector('.js-award-holder')
    end
  end
end
