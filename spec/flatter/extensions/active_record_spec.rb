require 'spec_helper'

module Flatter::Extensions
  ::Flatter.configure do |f|
    f.use :order
    f.use :active_record
  end

  module ActiveRecordSpec
    User = SpecModel(:users, email: :string) do
      has_one :person, class_name: 'Flatter::Extensions::ActiveRecordSpec::Person'
      has_many :phones, class_name: 'Flatter::Extensions::ActiveRecordSpec::Phone'
    end

    Person = SpecModel(:people, user_id: :integer, first_name: :string, last_name: :string) do
      belongs_to :user, class_name: 'Flatter::Extensions::ActiveRecordSpec::User'
    end

    Phone = SpecModel(:phones, user_id: :integer, number: :string) do
      belongs_to :user, class_name: 'Flatter::Extensions::ActiveRecordSpec::User'

      validates_inclusion_of :number, in: ['111-222-3333']
    end

    class UserMapper < ::Flatter::Mapper
      map user_email: :email

      validates_presence_of :user_email

      trait :registration do
        mount :person, foreign_key: :user_id, mapper_class_name: 'Flatter::Extensions::ActiveRecordSpec::PersonMapper'
        mount :phone, foreign_key: :user_id, mapper_class_name: 'Flatter::Extensions::ActiveRecordSpec::PhoneMapper'
      end
    end

    class PersonMapper < ::Flatter::Mapper
      map :first_name, :last_name

      validates_presence_of :last_name
    end

    class PhoneMapper < ::Flatter::Mapper
      map phone_number: :number
    end
  end

  RSpec.describe ActiveRecord do
    describe 'user registration scenario' do
      let(:new_user) { ActiveRecordSpec::User.new }
      let(:mapper)   { ActiveRecordSpec::UserMapper.new(new_user, :registration) }
      let(:registration_params) do
        { user_email:   'user@email.com',
          first_name:   'John',
          last_name:    'Smith',
          phone_number: '123-456-7890'}
      end

      describe 'registration trait' do
        it 'creates User record and all nested records' do
          expect_any_instance_of(ActiveRecordSpec::User).not_to receive(:save)
          expect_any_instance_of(ActiveRecordSpec::Person).not_to receive(:save)
          expect_any_instance_of(ActiveRecordSpec::Phone).not_to receive(:save)

          expect { expect { expect {
            expect(mapper.apply(registration_params))
          }.to change{ ActiveRecordSpec::User.count }.by(1)
          }.to change{ ActiveRecordSpec::Person.count }.by(1)
          }.to change{ ActiveRecordSpec::Phone.count }.by(1)
        end

        describe 'nested models' do
          let(:user) { ActiveRecordSpec::User.first }
          before     { mapper.apply(registration_params) }

          specify 'created with proper attributes' do
            expect(user.email).to eq 'user@email.com'
            expect(user.person.first_name).to eq 'John'
            expect(user.person.last_name).to eq 'Smith'
            expect(user.phones.first.number).to eq '123-456-7890'
          end
        end
      end
    end

    describe 'people management scenario' do
      let(:person) { ActiveRecordSpec::Person.new }
      let(:mapper) do
        ActiveRecordSpec::PersonMapper.new(person) do
          mount :user, mounter_foreign_key: :user_id, index: {save: -1}, mapper_class_name: 'Flatter::Extensions::ActiveRecordSpec::UserMapper' do
            mount :phone, foreign_key: :user_id, mapper_class_name: 'Flatter::Extensions::ActiveRecordSpec::PhoneMapper'
          end

          set_callback :validate, :before, :skip_empty

          def skip_empty
            mounting(:user).skip! if user_email.blank?
            mounting(:phone).skip! if mounting(:user).skipped? || phone_number.blank?
          end
        end
      end

      subject(:apply) { mapper.apply(params) }

      context 'with empty params' do
        let(:params) { {} }

        it 'does not create any record' do
          expect { expect { expect {
            expect(apply).to be false
            expect(mapper.errors.keys).to eq [:last_name]
          }.not_to change(ActiveRecordSpec::User, :count)
          }.not_to change(ActiveRecordSpec::Person, :count)
          }.not_to change(ActiveRecordSpec::Phone, :count)
        end
      end

      context 'when only person fields are specified' do
        let(:params) { {last_name: 'Smith', first_name: 'John'} }

        it 'creates only person record' do
          expect { expect { expect {
            expect(apply).to be true
          }.not_to change(ActiveRecordSpec::User, :count)
          }.to change(ActiveRecordSpec::Person, :count).by(1)
          }.not_to change(ActiveRecordSpec::Phone, :count)
        end
      end

      context 'when person and phone number fields are specified' do
        let(:params) { {last_name: 'Smith', first_name: 'John', phone_number: '123-456-7890'} }

        it 'creates only person record' do
          expect { expect { expect {
            expect(apply).to be true
          }.not_to change(ActiveRecordSpec::User, :count)
          }.to change(ActiveRecordSpec::Person, :count).by(1)
          }.not_to change(ActiveRecordSpec::Phone, :count)
        end
      end

      context 'when person and user fields are specified' do
        let(:params) { {last_name: 'Smith', first_name: 'John', user_email: 'user@email.com'} }

        it 'creates user and person records' do
          expect { expect { expect {
            expect(apply).to be true
          }.to change(ActiveRecordSpec::User, :count).by(1)
          }.to change(ActiveRecordSpec::Person, :count).by(1)
          }.not_to change(ActiveRecordSpec::Phone, :count)

          user = ActiveRecordSpec::User.first
          expect(user.email).to eq 'user@email.com'
          expect(user.person.first_name).to eq 'John'
          expect(user.person.last_name).to eq 'Smith'
        end
      end

      context 'when all fields are specified' do
        let(:params) do
          { last_name:    'Smith',
            first_name:   'John',
            user_email:   'user@email.com',
            phone_number: '123-456-7890' }
        end

        it 'creates user, person and phone records' do
          expect { expect { expect {
            expect(apply).to be true
          }.to change(ActiveRecordSpec::User, :count).by(1)
          }.to change(ActiveRecordSpec::Person, :count).by(1)
          }.to change(ActiveRecordSpec::Phone, :count).by(1)

          user = ActiveRecordSpec::User.first
          expect(user.email).to eq 'user@email.com'
          expect(user.person.first_name).to eq 'John'
          expect(user.person.last_name).to eq 'Smith'
          expect(user.phones.first.number).to eq '123-456-7890'
          expect(user.created_at).to be_present
          expect(user.updated_at).to be_present
          expect(user.person.created_at).to be_present
          expect(user.person.updated_at).to be_present
          expect(user.phones.first.created_at).to be_present
          expect(user.phones.first.updated_at).to be_present
        end
      end
    end
  end
end