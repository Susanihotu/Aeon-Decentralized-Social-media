// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./SocialToken.sol";

contract DecentralizedSocialMedia {
    struct UserProfile {
        string username;
        string bio;
        address[] followers;
        mapping(address => bool) isFollower;
    }

    struct Post {
        uint256 postId;
        address author;
        string content;
        bool isPrivate;
        uint256 timestamp;
        uint256 likes;
        uint256 dislikes;
        uint256 commentCount; 
        mapping(uint256 => Comment) comments;
        mapping(address => bool) hasReacted;  
    }

    struct Comment {
        address commenter;
        string content;
        uint256 timestamp;
    }

    uint256 public postCounter;
    SocialToken public socialToken;
    mapping(address => UserProfile) public userProfiles;
    mapping(uint256 => Post) public posts;

    event ProfileCreated(address indexed user, string username, string bio);
    event PostCreated(uint256 indexed postId, address indexed author, string content, bool isPrivate);
    event CommentAdded(uint256 indexed postId, address indexed commenter, string content);
    event ReactionAdded(uint256 indexed postId, address indexed user, bool liked);
    event FollowedUser(address indexed follower, address indexed followed);
    event UnfollowedUser(address indexed follower, address indexed unfollowed);

    modifier onlyProfileOwner(address user) {
        require(msg.sender == user, "Not the profile owner");
        _;
    }

    modifier postExists(uint256 postId) {
        require(posts[postId].timestamp != 0, "Post does not exist");
        _;
    }

    constructor(address _tokenAddress) {
        socialToken = SocialToken(_tokenAddress);
    }

    function createProfile(string calldata _username, string calldata _bio) external {
        UserProfile storage profile = userProfiles[msg.sender];
        require(bytes(profile.username).length == 0, "Profile already exists");

        profile.username = _username;
        profile.bio = _bio;

        emit ProfileCreated(msg.sender, _username, _bio);
    }

    function createPost(string calldata _content, bool _isPrivate) external {
        require(bytes(userProfiles[msg.sender].username).length > 0, "Profile not created");

        postCounter++;
        Post storage newPost = posts[postCounter];
        newPost.postId = postCounter;
        newPost.author = msg.sender;
        newPost.content = _content;
        newPost.isPrivate = _isPrivate;
        newPost.timestamp = block.timestamp;

        emit PostCreated(postCounter, msg.sender, _content, _isPrivate);
    }

    function addComment(uint256 _postId, string calldata _content) external postExists(_postId) {
        Post storage post = posts[_postId];

        require(
            !post.isPrivate || userProfiles[post.author].isFollower[msg.sender],
            "You are not allowed to comment on this post"
        );

        uint256 commentId = post.commentCount; 
        post.comments[commentId] = Comment({
            commenter: msg.sender,
            content: _content,
            timestamp: block.timestamp
        });

        post.commentCount++; 

        emit CommentAdded(_postId, msg.sender, _content);
    }

    function reactToPost(uint256 _postId, bool _like) external postExists(_postId) {
        Post storage post = posts[_postId];
        require(!post.hasReacted[msg.sender], "You have already reacted to this post");

        post.hasReacted[msg.sender] = true; 

        if (_like) {
            post.likes++;
            socialToken.mint(post.author, 10 * 10**socialToken.decimals());
        } else { 
            post.dislikes++;
        }

        emit ReactionAdded(_postId, msg.sender, _like);
    }

    function followUser(address _user) external {
        require(msg.sender != _user, "You cannot follow yourself");
        UserProfile storage profile = userProfiles[_user];

        require(!profile.isFollower[msg.sender], "Already following this user");

        profile.followers.push(msg.sender);
        profile.isFollower[msg.sender] = true;

        emit FollowedUser(msg.sender, _user);
    }

    function unfollowUser(address _user) external {
        UserProfile storage profile = userProfiles[_user];
        require(profile.isFollower[msg.sender], "Not following this user");

        uint256 length = profile.followers.length;
        for (uint256 i = 0; i < length; i++) {
            if (profile.followers[i] == msg.sender) {
                profile.followers[i] = profile.followers[length - 1]; 
                profile.followers.pop(); 
                break;
            }
        }

        profile.isFollower[msg.sender] = false;
        emit UnfollowedUser(msg.sender, _user);
    }

    function isFollowing(address _user, address _follower) external view returns (bool) {
        return userProfiles[_user].isFollower[_follower];
    }

    function getPost(uint256 _postId) external view postExists(_postId) returns (
        uint256 postId,
        address author,
        string memory content,
        bool isPrivate,
        uint256 timestamp,
        uint256 likes,
        uint256 dislikes,
        uint256 commentCount
    ) {
        Post storage post = posts[_postId];
        require(
            !post.isPrivate || post.author == msg.sender || userProfiles[post.author].isFollower[msg.sender],
            "This post is private"
        );

        return (
            post.postId,
            post.author,
            post.content,
            post.isPrivate,
            post.timestamp,
            post.likes,
            post.dislikes,
            post.commentCount 
        );
    }

    function getFollowers(address _user) external view returns (address[] memory) {
        return userProfiles[_user].followers;
    }

    function getComments(uint256 _postId) external view postExists(_postId) returns (
        address[] memory commenters,
        string[] memory contents,
        uint256[] memory timestamps
    ) {
        Post storage post = posts[_postId];
        uint256 length = post.commentCount;

        commenters = new address[](length);
        contents = new string[](length);
        timestamps = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            commenters[i] = post.comments[i].commenter;
            contents[i] = post.comments[i].content;
            timestamps[i] = post.comments[i].timestamp;
        }

        return (commenters, contents, timestamps);
    }
}
