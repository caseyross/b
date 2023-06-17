// Special extractor functions for API routes that need data restructuring beyond what the general extractor can provide.
import account from './account.coffee'
import collection from './collection.coffee'
import comment from './comment.coffee'
import post from './post.coffee'
import post_more_replies from './post_more_replies.coffee'
import subreddit_widgets from './subreddit_widgets.coffee'
import subreddits_popular from './subreddits_popular.coffee'
import user_multireddits_owned_public from './user_multireddits_owned_public.coffee'
import users from './users.coffee'

export default {
	account,
	collection,
	comment,
	post,
	post_more_replies,
	subreddit_widgets,
	subreddits_popular,
	user_multireddits_owned_public,
	users,
}