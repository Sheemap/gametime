package datastore

import (
	"errors"
	"gametime/internal/utils"
	"time"
)

type ClockEventType string
const (
	START ClockEventType = "START"
	STOP        = "STOP"
	ADD        = "ADD"
	SUB        = "SUB"
)

type ClockState string
const (
    RUNNING ClockState = "RUNNING"
    STOPPED  = "STOPPED"
)

type ClockEvent struct {
    EventType ClockEventType
    Timestamp time.Time
    RemainingTime time.Duration
    // The amount of time remaining on the clock when emitted
    Detail interface{}
}

func (c *Clock) RemainingTime(relativeTo *ClockEvent) time.Duration {
    return c.EventLog[len(c.EventLog)-1].RemainingTime
}

/// EndTime gets the projected end timestamp if the clock continuously runs without stopping
func (c *Clock) EndTime() time.Time {
    latestChange := c.latestStateChange()
    latestEvent := c.EventLog[len(c.EventLog)-1]
    return latestChange.Timestamp.Add(latestEvent.RemainingTime)
}

type Clock struct {
	ID            string
	Name          string
    EventLog      []ClockEvent
	Increment     time.Duration
	InitialTime time.Duration
}

var (
    ErrClockIsNotActive = errors.New("clock is not active")
    ErrClockIsAlreadyActive = errors.New("clock is already active")
)

func (c *Clock) latestStateChange() ClockEvent {
    relevant := utils.Filter(c.EventLog, func(ce ClockEvent) bool {
        return ce.EventType == START || ce.EventType == STOP
    })

    return relevant[len(relevant)-1]
}

func (c *Clock) State() ClockState {
    latest := c.latestStateChange()

    if latest.EventType == START {
        return RUNNING
    } else {
        return STOPPED
    }
}

func (c *Clock) getStopEvent() (*ClockEvent, error) {
    if c.State() != RUNNING {
        return nil, ErrClockIsNotActive
    }

    return &ClockEvent{
        EventType: STOP,
        Timestamp: time.Now(),
    }, nil
}

func (c *Clock) getStartEvent() (*ClockEvent, error) {
    if c.State() != STOPPED {
        return nil, ErrClockIsAlreadyActive
    }

    return &ClockEvent{
        EventType: START,
        Timestamp: time.Now(),
    }, nil
}

