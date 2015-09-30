require 'spec_helper'

module Flatter::Extensions
  ::Flatter.use :skipping

  module SkippingSpec
    class A
      include ActiveModel::Model

      attr_accessor :a1

      def b
        @b ||= B.new
      end
    end

    class B
      include ActiveModel::Model

      def save
        true
      end
    end

    class MapperA < ::Flatter::Mapper
      map :a1
      mount :b, mapper_class_name: 'Flatter::Extensions::SkippingSpec::MapperB'

      set_callback :save, :before, -> { mounting(:b).skip! if a1 == 'skip!' }
    end

    class MapperB < ::Flatter::Mapper
    end
  end

  RSpec.describe Skipping do
    let(:model)  { SkippingSpec::A.new }
    let(:mapper) { SkippingSpec::MapperA.new(model) }

    specify 'when conditions are met' do
      mapper.write(a1: 'skip!')
      expect_any_instance_of(SkippingSpec::B).not_to receive(:save)
      mapper.save
      expect(mapper.mounting(:b)).to be_skipped
    end

    specify 'when conditions are not met' do
      mapper.write(a1: 'a1')
      expect_any_instance_of(SkippingSpec::B).to receive(:save)
      mapper.save
    end
  end
end
