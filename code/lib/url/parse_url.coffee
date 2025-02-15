import api from 'rr-api'

FEED_PAGE_SIZE = 10
GEO_SEO_PREFIXES =
	['de', 'es', 'fr', 'it', 'pt']
POST_COMMENTS_INITIAL_SIZE = 100
RECOGNIZED_PRIMARY_PATH_SEGMENTS =
	['api', 'c', 'chat', 'collection', 'comments', 'contributor-program', 'dev', 'domain', 'gallery', 'gold', 'link', 'live', 'login', 'media', 'message', 'over18', 'p', 'poll', 'post', 'prefs', 'premium', 'r', 'reddits', 'register', 'report', 'rules', 'search', 'submit', 'subreddit', 'subreddits', 't', 'tb', 'u', 'user', 'users', 'video', 'w', 'wiki'] # front page sort options handled separately
RECOGNIZED_SUBREDDIT_PATH_SEGMENTS =
	['about', 'c', 'collection', 'comments', 'duplicates', 'mod', 'p', 'post', 'rules', 's', 'search', 'submit', 'w', 'wiki']
RECOGNIZED_USER_PATH_SEGMENTS =
	['comments', 'downvoted', 'gilded', 'hidden', 'm', 'messages', 'overview', 'posts', 'saved', 'submitted', 'upvoted']
SORT_OPTIONS_FEED =
	['best', 'controversial', 'hot', 'new', 'rising', 'search', 'top']
SORT_OPTIONS_FEED_SEARCH =
	['comments', 'relevance', 'new', 'top']
SORT_OPTIONS_FEED_USER =
	['controversial', 'hot', 'new', 'top']
SORT_OPTIONS_POST_COMMENTS =
	['confidence', 'controversial', 'new', 'old', 'qa', 'top']
TIMERANGE_OPTIONS =
	['all', 'day', 'hour', 'month', 'week', 'year']

export default (url) ->

	feed = {}
	post = {}
	wiki = {}

	preload = []

	unsupported = false

	#################
	# Parse URL query

	query = new URLSearchParams(decodeURI(url.search))
	feed.collection_id = query.get('c')
	feed.filter = query.get('filter')
	feed.multireddit_name = query.get('m')
	if query.get('search_sort') in SORT_OPTIONS_FEED_SEARCH
		feed.search_sort = query.get('search_sort')
	feed_flair_search = query.get('f')?.replaceAll('flair_name', 'flair')
	feed_text_search = query.get('search_text') or query.get('q')
	feed_combined_search = [feed_flair_search, feed_text_search].filter((x) -> x).join('+').replaceAll(':', '=').replaceAll(' ', '+')
	if feed_combined_search.length > 0
		feed.search_text = feed_combined_search
	if query.get('sort') in SORT_OPTIONS_FEED
		feed.sort = query.get('sort')
	feed.time_range =
		if query.get('t') in TIMERANGE_OPTIONS
			query.get('t')
		else
			'all'
	feed.user_name = query.get('u')
	if query.get('comment_sort') in SORT_OPTIONS_POST_COMMENTS
		post.comments_sort = query.get('comment_sort')
	post.focus_comment_id = query.get('comment')
	post.focus_comment_parent_count = query.get('context')
	wiki.page_version = query.get('v')

	################
	# Parse URL path

	path = url.pathname.split('/').map((x) -> decodeURIComponent(x).replaceAll(' ', '_'))
	# Strip empty leading/trailing segments.
	if path[0] is ''
		path.shift()
	if path.at(-1) is ''
		path.pop()
	if !path[0]?
		path[0] = 'reddit'
	# Strip global SEO prefixes (but keep r/de).
	if path[0] in GEO_SEO_PREFIXES and path[1] is 'r' and path[2]?
		path.shift()
	# Treat top-level paths as subreddit names unless we know otherwise.
	if path[0]? and path[0] not in RECOGNIZED_PRIMARY_PATH_SEGMENTS
		path.splice(0, 0, 'r')
	# Convert r/all and r/popular to normal multireddit format.
	if path[0] is 'r' and path[1] in ['all', 'popular']
		path.splice(0, 0, 'u')
	# Normalize subreddit post paths.
	if path[0] is 'r' and path[2]? and path[2] not in RECOGNIZED_SUBREDDIT_PATH_SEGMENTS and path[2] not in SORT_OPTIONS_FEED
		path.splice(2, 0, 'p')
		if path[4]?
			path.splice(4, 0, '_')
	# Normalize "user subreddit" post paths.
	if path[0] in ['u', 'user'] and path[2] is 'comments' and path[3]?
		path.splice(0, 2, 'r', 'u_' + path[1])
	# For user paths, treat third-level paths as multireddit names unless we know otherwise.
	if path[0] in ['u', 'user'] and path[2]? and path[2] not in RECOGNIZED_USER_PATH_SEGMENTS
		path.splice(2, 0, 'm')
	# Top-level wiki paths redirect to the r/reddit.com wiki.
	if path[0] in ['w', 'wiki']
		path.splice(0, 0, 'r', 'reddit.com')
	[ a, b, c, d, e, f, g ] = path
	switch a
		when 'c', 'collection'
			feed.collection_id = b
		when 'comments', 'p', 'post'
			post.id = b
			post.focus_comment_id = c if c?
			delete post.focus_comment_parent_count unless post.focus_comment_id?
			preload.push(api.ID('post', post.id, post.comments_sort or 'confidence', POST_COMMENTS_INITIAL_SIZE, post.focus_comment_id, post.focus_comment_parent_count))
		when 'message'
			feed.type = 'account_messages'
			switch b
				when 'compose' then unsupported = true
				when 'inbox' then feed.filter = 'inbox'
				when 'sent' then feed.filter = 'sent'
				when 'unread' then feed.filter = 'unread'
			feed.filter = 'unread' unless feed.filter
			feed.base_page_id = api.ID('account_messages', feed.filter, FEED_PAGE_SIZE)
		when 'r', 'subreddit'
			if b in ['friends', 'mod'] then unsupported = true
			else
				feed.subreddit_name = b
				if c is undefined or c in SORT_OPTIONS_FEED
					feed.sort = c if c in SORT_OPTIONS_FEED
				else switch c
					when 'c', 'collection'
						feed.collection_id = d
					when 'comments', 'p', 'post'
						post.id = d
						post.focus_comment_id = f if f?
						delete post.focus_comment_parent_count unless post.focus_comment_id?
						# best guess preload ID; we prefer to use `post.suggested_sort` but that's unknown at this stage
						preload.push(api.ID('post', post.id, post.comments_sort or 'confidence', POST_COMMENTS_INITIAL_SIZE, post.focus_comment_id, post.focus_comment_parent_count))
					when 'mod'
						feed.sort = 'modqueue'
					when 's'
						unsupported = true
					when 'search'
						feed.sort = 'search'
					when 'w', 'wiki'
						feed.type = 'subreddit_wikipages'
						wiki.subreddit_name = b
						wiki.page_name = [d, e, f, g].filter((x) -> x).join('/') or 'index'
						if wiki.page_name == 'pages' then wiki.page_name = 'index'
						preload.push(api.ID('subreddit_wikipage', wiki.subreddit_name, wiki.page_name, wiki.page_version))
		when 'u', 'user'
			feed.user_name = b
			switch c
				when 'comments'
					feed.type = 'user_comments'
					feed.sort = d if d in SORT_OPTIONS_FEED_USER
					if !feed.sort
						feed.sort = 'new'
					feed.base_page_id = api.ID('user_comments', feed.user_name, feed.time_range, feed.sort, FEED_PAGE_SIZE)
				when 'm'
					feed.multireddit_name = d
					switch e
						when 'search' then feed.sort = 'search'
						else feed.sort = e if e in SORT_OPTIONS_FEED
				when 'messages'
					feed.type = 'account_messages'
					feed.filter = 'unread' unless feed.filter
					feed.base_page_id = api.ID('account_messages', feed.filter, FEED_PAGE_SIZE)
				when 'posts', 'submitted'
					feed.sort = d if d in SORT_OPTIONS_FEED_USER
				when 'saved'
					switch d
						when 'comments' then feed.type = 'account_saved_comments'
						else feed.type = 'account_saved_posts'
					feed.base_page_id = api.ID(feed.type, feed.user_name, FEED_PAGE_SIZE)

	#############################################
	# Calculate derived parameters for post feeds

	if !feed?.type?
		if feed.collection_id
			feed.type = 'collection_posts'
		else if feed.multireddit_name
			feed.type = 'multireddit_posts'
		else if feed.user_name
			feed.type = 'user_posts'
		else if feed.subreddit_name
			feed.type = 'subreddit_posts'
	switch feed.type
		when 'collection_posts'
			feed.base_page_id = api.ID('collection', feed.collection_id)
		when 'multireddit_posts'
			feed.filter = 'unread' unless feed.filter
			switch
				when feed.user_name is 'r' and feed.multireddit_name is 'subscribed'
					feed.sort = 'best' unless feed.sort
					preload.push(api.ID('account_subscribed_subreddits', 25))
					preload.push(api.ID('subreddits_popular', 25))
				else
					feed.sort = 'hot' unless feed.sort
			switch feed.sort
				when 'search'
					feed.filter = 'all' unless feed.filter
					feed.search_sort = 'relevance' unless feed.search_sort
					if feed.search_text?
						feed.base_page_id = api.ID('search_posts', "multireddit=#{feed.user_name}-#{feed.multireddit_name}+#{feed.search_text}", 'all', feed.search_sort, FEED_PAGE_SIZE)
				else
					feed.filter = 'unread' unless feed.filter
					feed.base_page_id = api.ID('multireddit_posts', feed.user_name, feed.multireddit_name, feed.time_range, feed.sort, FEED_PAGE_SIZE)
			preload.push(api.ID('multireddit', feed.user_name, feed.multireddit_name))
		when 'subreddit_posts'
			feed.sort = 'hot' unless feed.sort
			switch feed.sort
				when 'modqueue'
					feed.filter = 'posts' unless feed.filter
					feed.base_page_id = api.ID("subreddit_modqueue_#{feed.filter}", feed.subreddit_name, FEED_PAGE_SIZE)
				when 'search'
					feed.filter = 'all' unless feed.filter
					feed.search_sort = 'relevance' unless feed.search_sort
					if feed.sort is 'search' and feed.search_text?
						feed.base_page_id = api.ID('search_posts', "subreddit=#{feed.subreddit_name}+#{feed.search_text}", 'all', feed.search_sort, FEED_PAGE_SIZE)
				else
					feed.filter = 'unread' unless feed.filter
					feed.base_page_id = api.ID('subreddit_posts', feed.subreddit_name, feed.time_range, feed.sort, FEED_PAGE_SIZE)
			preload.push(api.ID('subreddit', feed.subreddit_name))
		when 'user_posts'
			feed.filter = 'unread' unless feed.filter
			feed.sort = 'new' unless feed.sort
			feed.base_page_id = api.ID('user_posts', feed.user_name, feed.time_range, feed.sort, FEED_PAGE_SIZE)
			preload.push(api.ID('user', feed.user_name))

	##############################
	# Construct final route object

	if unsupported
		return {}
	else
		route = {}
		for object in [feed, post, wiki]
			for k, v of object
				if !v? then delete object[k]
		if feed.type
			route.feed = feed
			if feed.base_page_id
				preload.unshift(feed.base_page_id)
		if post.id
			route.post = post
		if wiki.page_name and wiki.subreddit_name
			route.wiki = wiki
		if preload.length > 0
			route.preload = preload
		return route
