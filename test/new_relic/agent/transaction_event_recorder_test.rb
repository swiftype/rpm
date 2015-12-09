# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require File.expand_path(File.join(File.dirname(__FILE__),'..','..','test_helper'))
require 'new_relic/agent/transaction_event_recorder'

module NewRelic
  module Agent
    class TransactionEventRecorderTest < Minitest::Test

      def setup
        @recorder = TransactionEventRecorder.new
        freeze_time
        @attributes = nil
      end

      def test_synthetics_events_overflow_to_transaction_buffer
        with_config :'synthetics.events_limit' => 10 do
          20.times do
            generate_request :synthetics_resource_id => 100
          end

          txn_events = harvest_transaction_events!
          syn_events = harvest_synthetics_events!

          assert_equal 10, txn_events.size
          assert_equal 10, syn_events.size
        end
      end

      def test_synthetics_events_timestamp_bumps_go_to_main_buffer
        with_config :'synthetics.events_limit' => 10 do
          10.times do |i|
            generate_request(:timestamp => i + 10, :synthetics_resource_id => 100)
          end

          generate_request(:timestamp => 1, :synthetics_resource_id => 100)

          txn_events = harvest_transaction_events!
          syn_events = harvest_synthetics_events!

          assert_equal 10, syn_events.size
          assert_equal 10.0, syn_events[0][0]["timestamp"]
          assert_equal 1, txn_events.size
        end
      end

      def generate_request options={}
        payload = {
          :name => "Controller/blogs/index",
          :type => :controller,
          :start_timestamp => options[:timestamp] || Time.now.to_f,
          :duration => 0.1,
          :attributes => attributes,
          :error => false
        }.merge(options)

        @recorder.record payload
      end

      def attributes
        if @attributes.nil?
          filter = NewRelic::Agent::AttributeFilter.new(NewRelic::Agent.config)
          @attributes = NewRelic::Agent::Transaction::Attributes.new(filter)
        end

        @attributes
      end

      def harvest_transaction_events!
        @recorder.transaction_event_aggregator.harvest!
      end

      def harvest_synthetics_events!
        @recorder.synthetics_event_aggregator.harvest!
      end
    end
  end
end
