#pragma once
/*******************************************************************************

	@file Quadtree.h

	@date 9/10/2020 3:57:44 PM

	@authors
	Christian Wookey (christian.wookey@digipen.edu)

	@brief
	Quadtree is used to reduce the number of collision checks.

	@copyright All content © copyright 2020-2021, DigiPen (USA) Corporation 

*******************************************************************************/

#include "AABB.h"
#include <list>
#include <array>
#include "CollisionManager.h"
#include "Updateable.h"

typedef class GameObject GameObject;

class Quadtree
{
public:

	/// <summary>
	/// Default constructor.
	/// </summary>
	/// <returns>A new Quadtree with the default settings</returns>
	Quadtree() noexcept : Quadtree(AABB(-10.f, 10.f, 10.f, 10.f)) {}

	/// <summary>
	/// Non-default constructor.
	/// </summary>
	/// <param name="bounds">The area that the Quadtree covers.</param>
	/// <returns>A new Quadtree with the specified bounds</returns>
	Quadtree(AABB bounds) noexcept : Quadtree(6, 8, bounds) {}

	/// <summary>
	/// Non-default constructor.
	/// </summary>
	/// <param name="maxDepth">Maximum depth of the tree</param>
	/// <param name="maxObjects">The maximum number of objects stored in one node.</param>
	/// <param name="bounds">The area that the Quadtree covers.</param>
	/// <returns>A new Quadtree with a specified  bounds, max depth and max objects.</returns>
	Quadtree(unsigned maxDepth, unsigned maxObjects, AABB bounds) noexcept;

	/// destructor
	~Quadtree() = default;
	
	Quadtree(const Quadtree&) = default;
	Quadtree& operator=(const Quadtree&) = default;
	
	/// delete move constructor
	Quadtree(Quadtree&&) = delete;
	/// delete move assignment operator
	Quadtree& operator=(Quadtree&&) = delete;



	/// Most of the public functions in Quadtree are helper functions which call the corresponding
	/// recursive function on the root node of the tree.

	/// <summary>
	/// Adds an object to the tree, branching if needed.
	/// </summary>
	/// <param name="object">A pointer to the GameObject to add.</param>
	/// <returns>true if the object was inserted successfully, false otherwise.</returns>
	bool Insert(_In_ GameObject* object);
	
	/// <summary>
	/// Find and removes an object from the tree.
	/// </summary>
	/// <param name="object">A pointer to the GameObject to remove.</param>
	/// <returns>true if the object was found, false otherwise.</returns>
	bool Remove(_In_ GameObject* object);

	/// <summary>
	/// Clears the quadtree of all objects and nodes.
	/// </summary>
	void Clear();

	/// <summary>
	/// Sets a new size for the quadtree.
	/// </summary>
	/// <param name="newBounds">The new size of the quadtree.</param>
	void Resize(const AABB& newBounds);

	/// <summary>
	/// Given a GameObject, find all the objects in the tree that overlap its AABB.
	/// </summary>
	/// <param name="object">A pointer to the GameObject to check</param>
	/// <param name="collisionCandidates">A reference to a vector of GameObject*</param>
	void GetCollisionCandidates(_In_ GameObject* object, _Inout_ std::vector<GameObject*>& collisionCandidates) noexcept;

	/// <summary>
	/// Gets the bounds.
	/// </summary>
	/// <returns>A constant AABB reference to the bounds of the tree.</returns>
	const AABB& GetBounds() const noexcept;

#ifdef _DEBUG
	/// <summary>
	/// Draws a debug version of the tree using ImGui.
	/// </summary>
	/// <param name="drawNodes">Should Quadtree nodes be drawn?</param>
	/// <param name="drawAABB">Should the object's AABB be drawn?</param>
	void Draw(bool drawCollider = true, bool drawAABB = false, bool drawNodes = false);
#endif // _DEBUG
	
	/// <summary>
	/// Counts Drawthe total number objects in the tree.
	/// </summary>
	/// <returns>the total number objects in the tree</returns>
	unsigned GetTotalObjects() noexcept;

protected:

	/// <summary>
	/// A Node is a single division of a Quadtree.
	/// The Quadtree starts with one root node, and each node has 4 children.
	/// </summary>
	class Node
	{
	public:
		// no default constructor
		Node() = delete;

		/// <summary>
		/// Non-default constructor.
		/// </summary>
		/// <param name="depth">The depth of the node. 0 is root.</param>
		/// <param name="bounds">The size of the node.</param>
		/// <param name="parent">The parent node of this node. If nullptr, the node is a root.</param>
		/// <param name="tree">The tree that owns this node.</param>
		/// <returns>A new Node.</returns>
		Node(unsigned depth, AABB bounds, Node* parent, Quadtree* tree) noexcept : depth_(depth), bounds_(bounds), parent_(parent), tree_(tree) {}
		
		/// <summary>
		/// Inserts a GameObject into the Quadtree
		/// </summary>
		/// <param name="object"></param>
		/// <returns>true if the object was inserted successfully, false otherwise.</returns>
		bool Insert(_In_ GameObject* object);

		/// <summary>
		/// Find and removes an object from the tree.
		/// </summary>
		/// <param name="object">A pointer to the GameObject to remove.</param>
		/// <returns>true if the object was found, false otherwise.</returns>
		bool Remove(_In_ GameObject* object);

		/// <summary>
		/// Given a GameObject, find all the objects in the tree that overlap its AABB.
		/// </summary>
		/// <param name="object">A pointer to the GameObject to check</param>
		/// <param name="collisionCandidates">A reference to a vector of GameObject*</param>
		void GetCollisionCandidates(_In_ GameObject* object, _Inout_ std::vector<GameObject*>& collisionCandidates) noexcept;

		/// <summary>
		/// Gets the bounds.
		/// </summary>
		/// <returns>A constant AABB reference to the bounds of the node.</returns>
		const AABB& GetBounds() const noexcept;

		/// <summary>
		/// Sets the bounds.
		/// </summary>
		/// <param name="aabb">The new bounds for the node.</param>
		/// <returns></returns>
		void SetBounds(const AABB& aabb) noexcept;

		/// <summary>
		/// Recursively clears a node of all objects and children underneath it.
		/// </summary>
		void Clear();

#ifdef _DEBUG
		/// <summary>
		/// Draws a quadnode.
		/// </summary>
		/// <param name="drawNodes">Should Quadtree nodes be drawn?</param>
		/// <param name="drawAABB">Should the object's AABB be drawn?</param>
		void Draw(bool drawCollider = true, bool drawAABB = false, bool drawNodes = false);
#endif // _DEBUG


	private:

		friend class Quadtree;

		/// <summary>
		/// Searches the Node recursively for overlapping GameObjects. Helper function for GetCollisionCandidates.
		/// </summary>
		/// <param name="object">The object to search for.</param>
		/// <param name="potentialCollisions">A reference to a vector of GameObject* that may collide with the object.</param>
		/// <returns></returns>
		void Search(_In_ GameObject* object, _Inout_ std::vector<GameObject*>& potentialCollisions) noexcept;
		
		/// <summary>
		/// 
		/// </summary>
		void Branch();
		
		/// <summary>
		/// Evaluates a Quadtree Node to see if its children can be collapsed.
		/// Used by Remove().
		/// </summary>
		void EvaluateChildren();
		
		/// <summary>
		/// Calculates the total number of GameObjects stored by this Node and its children (recursive).
		/// </summary>
		/// <returns>The count of GameObjects</returns>
		unsigned GetObjectCountInNode();

		/// <summary>
		/// Recursively searches the node to find where an object with a certain bounds would be stored.
		/// Branches the tree if needed.
		/// Helper function for Insert().
		/// </summary>
		/// <param name="objectBounds">The bounds of the GameObject to insert.</param>
		/// <returns>A pointer to the Node that the GameObject should be added to.</returns>
		Quadtree::Node* GetNodeForInsertion(_In_ const AABB& objectBounds);
		
		/// <summary>
		/// Recursively searches the node to find where an object with a certain bounds would be stored.
		/// Helper function for Search()
		/// </summary>
		/// <param name="objectBounds">The bounds of the GameObject to find.</param>
		/// <returns>A pointer to the Node that the GameObject should be in.</returns>
		Quadtree::Node* GetNodeForSearch(_In_ const AABB& objectBounds) noexcept;

		/// <summary>
		/// The depth of the node. 0 is root, 1 is first division, 2 is second, etc.
		/// </summary>
		unsigned depth_;
		
		/// <summary>
		/// The area this node covers.
		/// </summary>
		AABB bounds_;
		
		/// <summary>
		/// The parent of this node.
		/// </summary>
		Node* parent_;
		
		/// <summary>
		/// The Quadtree this node belongs to.
		/// </summary>
		Quadtree* tree_;
		
		/// <summary>
		/// The children of this Node.
		/// </summary>
		std::array<std::shared_ptr<Node>, 4> children_;
		
		/// <summary>
		/// The GameObjects that are stored in this Node.
		/// </summary>
		std::list<GameObject*> objects_;
	};


private:

	/// <summary>
	/// The root Node of the tree.
	/// </summary>
	std::shared_ptr<Quadtree::Node> root_;

	/// <summary>
	/// The maximum depth of the tree.
	/// </summary>
	unsigned maxDepth_;

	/// <summary>
	/// The maximum number of objects allowed in a single node.
	/// </summary>
	unsigned maxObjects_;

	/// <summary>
	/// The total objects stored in the tree.
	/// </summary>
	unsigned totalObjects_;

};

