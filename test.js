var redux = require('redux');
var R = require("ramda")

const ONLINE = 'ONLINE';

const defaultState = {
    user: 'CamperBot',
    status: 'offline',
    friends: '732,982',
    community: 'Free Code Camp'
};

const immutableReducer = (state = defaultState, action) => {
    switch(action.type) {
        case ONLINE:
            return R.merge(state, {status: action.type});
default:
    return state;
}
};

const wakeUp = () => {
    return {
        type: ONLINE
    }
};

const store = redux.createStore(immutableReducer);

store.subscribe(() => {
    console.log("Subscriber notified with", store.getState())
})

store.dispatch(wakeUp());

let s = store.getState()
s.friends = "0"
