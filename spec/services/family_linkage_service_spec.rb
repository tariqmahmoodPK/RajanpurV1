# frozen_string_literal: true

require 'rails_helper'

describe FamilyLinkageService do
  before(:each) { clean_data(User, Child, Family) }

  let(:user) do
    user = User.new(user_name: 'user_cp', full_name: 'Test User CP')
    user.save(validate: false) && user
  end

  let(:family1) do
    Family.create!(
      data: {
        family_number: '40bf9109',
        module_id: PrimeroModule::CP,
        family_size: 1,
        family_notes: 'Notes about the family',
        family_members: [
          {
            unique_id: '001',
            family_relationship: 'relationship1',
            family_relationship_notes: 'Notes about the relationship',
            family_relationship_notes_additional: 'Additional notes about the relationship',
            relation_name: 'MemberFirst MemberLast',
            relation_nickname: 'Member 1 Nickname',
            relation_sex: 'male',
            relation_age: 10,
            relation_date_of_birth: Date.today - 10.years,
            relation_age_estimated: true,
            relation_national_id: 'national_001',
            relation_other_id: 'other_001',
            relation_ethnicity: 'ethnicity1',
            relation_sub_ethnicity1: 'ethnicity2',
            relation_sub_ethnicity2: 'ethnicity3',
            relation_language: 'language1',
            relation_religion: 'religion1',
            relation_address_current: 'Current Address',
            relation_landmark_current: 'Current Landmark',
            relation_location_current: 'abc001',
            relation_address_is_permanent: false,
            relation_telephone: '22222222'
          },
          {
            unique_id: '002',
            relation_name: 'Member 2',
            relation_sex: 'male',
            relation_age: 12
          }
        ]
      }
    )
  end

  let(:family2) do
    family = Family.new_with_user(
      user,
      {
        family_number: '5fba4918',
        family_members: [
          { unique_id: 'f5775818', relation_sex: 'male' },
          { unique_id: '14397418', relation_sex: 'female' }
        ]
      }
    )
    family.save!
    family
  end

  let(:child_without_family) do
    child = Child.new_with_user(
      user,
      {
        age: 5,
        sex: 'male',
        family_details_section: [{ unique_id: '672f56fd', relation_sex: 'female' }]
      }
    )
    child.save!
    child
  end

  let(:child_with_family) do
    child = Child.new_with_user(user, { age: 5, sex: 'male' })
    child.family = family2
    child.family_member_id = 'f5775818'
    child.save!
    child
  end

  describe 'new_child_from_family_member' do
    it 'creates a child record using the family member data' do
      child = family1.new_child_from_family_member(user, '001')
      child.save!

      target_fields = FamilyLinkageService::DEFAULT_MAPPING.map { |mapping| mapping[:target] }.flatten

      expect(Child.find(child.id).data.select { |key, _value| target_fields.include?(key) }).to eq(
        {
          'name_first' => 'MemberFirst',
          'name_middle' => nil,
          'name_last' => 'MemberLast',
          'name_nickname' => 'Member 1 Nickname',
          'sex' => 'male',
          'age' => 10,
          'date_of_birth' => Date.today - 10.years,
          'estimated' => true,
          'national_id_no' => 'national_001',
          'other_id_no' => 'other_001',
          'ethnicity' => 'ethnicity1',
          'sub_ethnicity_1' => 'ethnicity2',
          'sub_ethnicity_2' => 'ethnicity3',
          'language' => 'language1',
          'religion' => 'religion1',
          'address_current' => 'Current Address',
          'landmark_current' => 'Current Landmark',
          'location_current' => 'abc001',
          'address_is_permanent' => false,
          'telephone_current' => '22222222'
        }
      )
    end
  end

  describe 'family_member_to_child' do
    it 'splits the relation name of the family member' do
      child = FamilyLinkageService.family_member_to_child(
        user, { 'unique_id' => '001', 'relation_name' => 'MemberFirst MemberLast' }
      )

      expect(child.name_first).to eq('MemberFirst')
      expect(child.name_middle).to be_nil
      expect(child.name_last).to eq('MemberLast')
    end

    it 'splits the relation name of the family member with middle name' do
      child = FamilyLinkageService.family_member_to_child(
        user, { 'unique_id' => '001', 'relation_name' => 'MemberFirst MemberMiddle MemberLast' }
      )

      expect(child.name_first).to eq('MemberFirst')
      expect(child.name_middle).to eq('MemberMiddle')
      expect(child.name_last).to eq('MemberLast')
    end

    it 'splits the relation name of the family member with a long middle name' do
      child = FamilyLinkageService.family_member_to_child(
        user, { 'unique_id' => '001', 'relation_name' => 'MemberFirst MemberMiddle1 MemberMiddle2 MemberMiddle3 MemberLast' }
      )

      expect(child.name_first).to eq('MemberFirst')
      expect(child.name_middle).to eq('MemberMiddle1 MemberMiddle2 MemberMiddle3')
      expect(child.name_last).to eq('MemberLast')
    end

    it 'splits the relation name of the family member but only sets the first name' do
      child = FamilyLinkageService.family_member_to_child(
        user, { 'unique_id' => '001', 'relation_name' => 'MemberFirst' }
      )

      expect(child.name_first).to eq('MemberFirst')
      expect(child.name_middle).to be_nil
      expect(child.name_last).to be_nil
    end
  end

  describe 'child_to_family_member' do
    it 'sets the relation_name from the name fields' do
      child = Child.create!(data: { name_first: 'FirstName', name_last: 'LastName', age: 10, sex: 'male' })
      family_member = FamilyLinkageService.child_to_family_member(child)
      expect(family_member['relation_name']).to eq('FirstName LastName')
    end

    it 'sets the relation_name from the name field' do
      child = Child.create!(data: { name: 'FirstName LastName', age: 10, sex: 'male' })
      family_member = FamilyLinkageService.child_to_family_member(child)
      expect(family_member['relation_name']).to eq('FirstName LastName')
    end
  end

  describe 'family_to_child' do
    it 'returns the family details for a child' do
      family_details = FamilyLinkageService.family_to_child(family1)

      expect(family_details['family_number']).to eq('40bf9109')
      expect(family_details['family_size']).to eq(1)
      expect(family_details['family_notes']).to eq('Notes about the family')
    end
  end

  describe 'new_family_linked_child' do
    context 'when the child is not linked to a family' do
      it 'returns a case linked to a family with the cases as members' do
        linked_child = FamilyLinkageService.new_family_linked_child(user, child_without_family, '672f56fd')
        child_without_family.save!
        linked_child.save!

        expect(linked_child.family.id).not_to be_nil
        expect(linked_child.family_member_id).to eq('672f56fd')
        expect(linked_child.family.family_members.size).to eq(2)
        expect(linked_child.family.family_members.map { |member| member['relation_sex'] }).to match_array(
          %w[male female]
        )
        expect(linked_child.family.family_members.map { |member| member['case_id'] }).to match_array(
          [linked_child.id, child_without_family.id]
        )
        expect(linked_child.family.family_members.map { |member| member['case_id_display'] }).to match_array(
          [linked_child.case_id_display, child_without_family.case_id_display]
        )
      end
    end

    context 'when the child is linked to a family' do
      it 'returns a case linked to a family with the cases as members' do
        linked_child = FamilyLinkageService.new_family_linked_child(user, child_with_family, '14397418')
        linked_child.save!

        expect(linked_child.family.id).to eq(family2.id)
        expect(linked_child.family_member_id).to eq('14397418')
        expect(linked_child.family.family_members.size).to eq(2)
        expect(linked_child.family.family_members.map { |member| member['relation_sex'] }).to match_array(
          %w[male female]
        )
        expect(linked_child.family.family_members.map { |member| member['case_id'] }).to match_array(
          [linked_child.id, child_with_family.id]
        )
        expect(linked_child.family.family_members.map { |member| member['case_id_display'] }).to match_array(
          [linked_child.case_id_display, child_with_family.case_id_display]
        )
      end
    end
  end

  describe '.calculate_family_member_record_user_access' do
    let(:role) do
      Role.create_or_update!(name: 'Test Role 1', unique_id: 'test-role-1',
                             permissions: Permission::RESOURCE_ACTIONS.slice('case'))
    end

    let(:user1) do
      user = User.new(user_name: 'user_cp', full_name: 'Test User CP', role:)
      user.save(validate: false) && user
    end

    let(:user2) do
      user = User.new(user_name: 'user_mgr_cp', full_name: 'Test User Mgr CP', role:)
      user.save(validate: false) && user
    end

    let(:family_member1) do
      { 'unique_id' => '48ca2f90', 'relation_sex' => 'male',
        'case_id' => '530e67c2-81fa-41ee-aa7b-b98b552954ca' }
    end

    let(:family_member2) do
      { 'unique_id' => 'b57374ec', 'relation_sex' => 'male', 'case_id' => '98e25d95-1365-4ae9-afd0-53f18e86a101' }
    end

    let(:family4) do
      family = Family.new_with_user(
        user1,
        {
          family_number: 'fc3f17e',
          family_members: [family_member1, family_member2]
        }
      )
      family.save!
      family
    end

    let(:child1) do
      child = Child.new_with_user(user1, { age: 6, sex: 'male' })
      child.id = '530e67c2-81fa-41ee-aa7b-b98b552954ca'
      child.family = family4
      child.family_member_id = 'f5775818'
      child.family_details_section = [
        { 'unique_id' => 'b57374ec', 'relation' => 'brother' }
      ]
      child.save!
      child
    end

    let(:child2) do
      child = Child.new_with_user(user2, { age: 7, sex: 'male' })
      child.id = '98e25d95-1365-4ae9-afd0-53f18e86a101'
      child.family = family4
      child.family_member_id = 'f5775818'
      child.family_details_section = [
        { 'unique_id' => '48ca2f90', 'relation' => 'brother' }
      ]
      child.save!
      child
    end

    before(:each) do
      child1
      child2
      user2
    end

    context 'when user have access to the case' do
      it 'return can_read_record true' do
        expect(
          FamilyLinkageService.calculate_family_member_record_user_access(
            family_member1, family4, user1
          )['can_read_record']
        ).to be true
      end
    end

    context 'when user does not have access to the case' do
      it 'return can_read_record false' do
        expect(
          FamilyLinkageService.calculate_family_member_record_user_access(
            family_member2, family4, user1
          )['can_read_record']
        ).to be false
      end
    end
  end
end
