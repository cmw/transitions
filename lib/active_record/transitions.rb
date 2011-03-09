# Copyright (c) 2009 Rick Olson

# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

module ActiveRecord
  module Transitions
    extend ActiveSupport::Concern

    included do
      include ::Transitions
      after_initialize :set_initial_state
      # state = state.to_sym would result in state_changed? otherwise
      before_validation do |record|
        record.state = record.state.to_s
      end
      validates_presence_of :state
      validate :state_inclusion
      # trigger :exit and :enter events if state was set manually 
      before_save do |record|
        if record.state_changed?
          machine = record.class.state_machine
          machine.state_index[record.state_was.try(:to_sym)].try(:call_action, :exit, record)
          machine.state_index[record.state.to_sym].call_action(:enter, record)
        end
      end      
    end

    def reload
      super.tap do
        self.class.state_machines.values.each do |sm|
          varnames = sm.state_index.values.inject([sm.current_state_variable]) do |hsh, st|
              hsh << st.instance_variable_name(:enter)
              hsh << st.instance_variable_name(:exit)
            end
          varnames.each do |varname|
            remove_instance_variable(varname) if instance_variable_defined?(varname)
          end
        end
      end
    end

    protected

    def write_state(state_machine, state)
      ivar = state_machine.current_state_variable
      prev_state = current_state(state_machine.name)
      instance_variable_set(ivar, state)
      self.state = state.to_s
      save!
    rescue ActiveRecord::RecordInvalid
      self.state = prev_state.to_s
      instance_variable_set(ivar, prev_state)
      raise
    end

    def read_state(state_machine)
      self.state && self.state.to_sym
    end

    def set_initial_state
      self.state ||= self.class.state_machine.initial_state.to_s
    end

    def state_inclusion
      unless self.class.state_machine.states.map{|s| s.name.to_s }.include?(self.state.to_s)
        self.errors.add(:state, :inclusion, :value => self.state)
      end
    end
  end
end

