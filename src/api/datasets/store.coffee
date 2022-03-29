import routes from './routes.coffee'
import extractGeneral from './extractors/general/extract.coffee'
import extractSpecial from './extractors/special/extract.coffee'

store = {}
subscribers = new Map()
keyedSubscribers = new Map()

publishTo = (subscriber) ->
	subscriber(store)

publishToAll = ->
	console.table store
	subscribers.forEach(publishTo)

publishKeyTo = (subscriber, key) ->
	subscriber(store[key])

publishKeyToAll = (key) ->
	if keyedSubscribers.has(key)
		keyedSubscribers.get(key).forEach((subscriber) ->
			publishKeyTo(subscriber, key)
		)

setLoading = (id) ->
	store[id] = {
		loading: true
	}

setError = (id, error) ->
	store[id] = {
		loading: false
		error: error
	}

setData = (id, data, partial) ->
	store[id] = {
		loading: false
		error: false
		partial: partial ? false
		data: data
		asOf: Date.now()
	}

export default {

	load: (id) ->
		setLoading(id)
		publishToAll()
		publishKeyToAll(id)
		request = routes[id.idType] ? Promise.reject()
		request(...id.idSpecs)
			.then((rawData) ->
				extract = extractSpecial[id.idType] ? extractGeneral
				extract(rawData)
			)
			.catch((error) ->
				setError(id, error)
				publishToAll()
				publishKeyToAll(id)
				throw error
			)
			.then(({ main, sub }) ->
				changed = [id]
				setData(id, main.data, main.partial)
				for object in sub
					changed.push(object.id)
					setData(object.id, object.data, object.partial)
				publishToAll()
				for key in changed
					publishKeyToAll(key)
				return main.data
			)

	subscribe: (subscriber) ->
		publishTo(subscriber)
		id = Symbol()
		subscribers.set(id, subscriber)
		return -> subscribers.delete(id)

	subscribeToKey: (key, subscriber) ->
		publishKeyTo(subscriber, key)
		id = Symbol()
		if !keyedSubscribers.has(key)
			keyedSubscribers.set(key, new Map())
		keyedSubscribers.get(key).set(id, subscriber)
		return -> keyedSubscribers.get(key).delete(id)

}