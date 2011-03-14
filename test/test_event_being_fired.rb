require "helper"

class TestEventBeingFired < Test::Unit::TestCase
  test "should raise an Transitions::InvalidTransition error if the transitions are empty" do
    event = Transitions::Event.new(nil, :event)

    assert_raise Transitions::InvalidTransition do
      event.fire(nil)
    end
  end

  test "should return the state of the first matching transition it finds" do
    event = Transitions::Event.new(nil, :event) do
      transitions :to => :closed, :from => [:open, :received]
    end

    obj = stub
    obj.stubs(:current_state).returns(:open)

    assert_equal :closed, event.fire(obj)
  end

  test "should match transitions from :any" do
    event = Transitions::Event.new(nil, :event) do
      transitions :to => :closed, :from => :any
    end

    obj = stub
    obj.stubs(:current_state).returns(:open)

    assert_equal :closed, event.fire(obj)
  end

  test "should not use transitions from :any if other transitions match" do
    event = Transitions::Event.new(nil, :event) do
      transitions :to => :closed, :from => :any
      transitions :to => :received, :from => :open
    end

    obj = stub
    obj.stubs(:current_state).returns(:open)

    assert_equal :received, event.fire(obj)
  end
end
