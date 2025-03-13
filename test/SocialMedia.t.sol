// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/SocialToken.sol";
import "../src/DecentralizedSocialMedia.sol";

contract DecentralizedSocialMediaTest is Test {
    SocialToken socialToken;
    DecentralizedSocialMedia socialMedia;
    address owner = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);

    function setUp() public {
        socialToken = new SocialToken();
        socialMedia = new DecentralizedSocialMedia(address(socialToken));
    }

    function testCreateProfile() public {
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit DecentralizedSocialMedia.ProfileCreated(user1, "Alice", "Blockchain Enthusiast");
        socialMedia.createProfile("Alice", "Blockchain Enthusiast");

        (string memory username, string memory bio) = socialMedia.userProfiles(user1);
        assertEq(username, "Alice");
        assertEq(bio, "Blockchain Enthusiast");
    }

    function testCannotCreateDuplicateProfile() public {
        vm.prank(user1);
        socialMedia.createProfile("Alice", "Blockchain Enthusiast");
        
        vm.prank(user1);
        vm.expectRevert("Profile already exists");
        socialMedia.createProfile("Alice", "Blockchain Dev");
    }

    function testCreatePost() public {
        vm.prank(user1);
        socialMedia.createProfile("Alice", "Blockchain Enthusiast");

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit DecentralizedSocialMedia.PostCreated(1, user1, "Hello, world!", false);
        socialMedia.createPost("Hello, world!", false);

        (uint256 postId, address author, string memory content, , , uint256 likes, uint256 dislikes, uint256 commentCount) = socialMedia.getPost(1);

        assertEq(author, user1);
        assertEq(content, "Hello, world!");
        assertEq(likes, 0);
        assertEq(dislikes, 0);
        assertEq(commentCount, 0);
    }

    function testCannotCreatePostWithoutProfile() public {
        vm.prank(user1);
        vm.expectRevert("Profile not created");
        socialMedia.createPost("Hello, world!", false);
    }

    function testFollowUser() public {
        vm.prank(user1);
        socialMedia.createProfile("Alice", "Blockchain Enthusiast");

        vm.prank(user2);
        socialMedia.createProfile("Bob", "Smart Contract Dev");

        vm.prank(user2);
        vm.expectEmit(true, true, false, true);
        emit DecentralizedSocialMedia.FollowedUser(user2, user1);
        socialMedia.followUser(user1);

        address[] memory followers = socialMedia.getFollowers(user1);
        assertEq(followers.length, 1);
        assertEq(followers[0], user2);
    }

    function testCannotFollowSelf() public {
        vm.prank(user1);
        socialMedia.createProfile("Alice", "Blockchain Enthusiast");
        
        vm.prank(user1);
        vm.expectRevert("You cannot follow yourself");
        socialMedia.followUser(user1);
    }

    function testUnfollowUser() public {
        vm.prank(user1);
        socialMedia.createProfile("Alice", "Blockchain Enthusiast");

        vm.prank(user2);
        socialMedia.createProfile("Bob", "Smart Contract Dev");

        vm.prank(user2);
        socialMedia.followUser(user1);

        assertTrue(socialMedia.isFollowing(user1, user2));

        vm.prank(user2);
        vm.expectEmit(true, true, false, true);
        emit DecentralizedSocialMedia.UnfollowedUser(user2, user1);
        socialMedia.unfollowUser(user1);

        assertFalse(socialMedia.isFollowing(user1, user2));
    }

    function testCannotUnfollowIfNotFollowing() public {
        vm.prank(user1);
        vm.expectRevert("Not following this user");
        socialMedia.unfollowUser(user2);
    }

    function testReactToPost() public {
        vm.prank(user1);
        socialMedia.createProfile("Alice", "Blockchain Enthusiast");

        vm.prank(user1);
        socialMedia.createPost("Hello, world!", false);

        vm.prank(user2);
        vm.expectEmit(true, true, false, true);
        emit DecentralizedSocialMedia.ReactionAdded(1, user2, true);
        socialMedia.reactToPost(1, true);

        (uint256 postId, , , , , uint256 likes, uint256 dislikes, uint256 commentCount) = socialMedia.getPost(1);

        assertEq(likes, 1);
        assertEq(dislikes, 0);
    }

    function testCannotReactTwice() public {
        vm.prank(user1);
        socialMedia.createProfile("Alice", "Blockchain Enthusiast");

        vm.prank(user1);
        socialMedia.createPost("Hello, world!", false);

        vm.prank(user2);
        socialMedia.reactToPost(1, true);

        vm.startPrank(user2);
        vm.expectRevert("You have already reacted to this post");
        socialMedia.reactToPost(1, false);
        vm.stopPrank();
    }

    function testCannotReactToNonexistentPost() public {
        vm.prank(user1);
        vm.expectRevert("Post does not exist");
        socialMedia.reactToPost(1, true);
    }

    function testAddComment() public {
        vm.prank(user1);
        socialMedia.createProfile("Alice", "Blockchain Enthusiast");

        vm.prank(user1);
        socialMedia.createPost("Hello, world!", false);

        vm.prank(user2);
        vm.expectEmit(true, true, false, true);
        emit DecentralizedSocialMedia.CommentAdded(1, user2, "Nice post!");
        socialMedia.addComment(1, "Nice post!");

        (address[] memory commenters, string[] memory contents, uint256[] memory timestamps) = socialMedia.getComments(1);

        assertEq(commenters.length, 1);
        assertEq(commenters[0], user2);
        assertEq(contents[0], "Nice post!");
        assertGt(timestamps[0], 0);
    }

    function testCannotCommentOnPrivatePostWithoutFollowing() public {
        vm.prank(user1);
        socialMedia.createProfile("Alice", "Blockchain Enthusiast");

        vm.prank(user1);
        socialMedia.createPost("Secret Post", true);

        vm.prank(user2);
        vm.expectRevert("You are not allowed to comment on this post");
        socialMedia.addComment(1, "Nice post!");
    }

    function testGetPost_PrivateAccess() public {
        vm.prank(user1);
        socialMedia.createProfile("Alice", "Blockchain Enthusiast");

        vm.prank(user1);
        socialMedia.createPost("Secret Post", true);

        vm.prank(user2);
        vm.expectRevert("This post is private");
        socialMedia.getPost(1);
    }

    function testGetComments_Empty() public {
        vm.prank(user1);
        socialMedia.createProfile("Alice", "Blockchain Enthusiast");

        vm.prank(user1);
        socialMedia.createPost("Hello, world!", false);

        (address[] memory commenters, , ) = socialMedia.getComments(1);

        assertEq(commenters.length, 0);
    }
}
