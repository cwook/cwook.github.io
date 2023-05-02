#pragma once
#include "stdafx.h"
/*******************************************************************************

	@file Quadtree.cpp

	@date 9/10/2020 3:57:44 PM

	@authors
	Christian Wookey (christian.wookey@digipen.edu)

	@brief
	Quadtree is used to reduce the number of collision checks.

	@copyright All content © copyright 2020-2021, DigiPen (USA) Corporation 

*******************************************************************************/

#include "Quadtree.h"
#include "GameObject.h"
#include "ColliderComponent.h"
#include "TransformUtility.h"
#include "DebugUtils.h"
#include "Camera.h"
#include "DebugDraw.h"

/*****************************************************************************/
/*								TREE IMPLEMENTATION		                     */
/*****************************************************************************/
/*****************************************************************************/
/*                             PUBLIC FUNCTIONS                              */
/*****************************************************************************/
Quadtree::Quadtree(unsigned maxLevels, unsigned maxObjects, AABB bounds) noexcept : maxDepth_(maxLevels), maxObjects_(maxObjects), totalObjects_(0)
{
	root_ = std::make_shared<Quadtree::Node>(0, bounds, nullptr, this);
}

bool Quadtree::Insert(_In_ GameObject* object)
{
	return root_->Insert(object);
}

bool Quadtree::Remove(_In_ GameObject* object)
{
	return root_->Remove(object);
}

void Quadtree::Clear()
{
	root_->Clear();
}

void Quadtree::Resize(const AABB& newBounds)
{
	this->root_->SetBounds(newBounds);
	this->root_->EvaluateChildren();
}

void Quadtree::GetCollisionCandidates(_In_ GameObject* object, _Inout_ std::vector<GameObject*>& collisionCandidates) noexcept
{
	root_->GetCollisionCandidates(object, collisionCandidates);
}

const AABB& Quadtree::GetBounds() const noexcept
{
	return root_->GetBounds();
}

#ifdef _DEBUG
void Quadtree::Draw(bool drawCollider, bool drawAABB, bool drawNodes)
{
	/*
	const AABB& aabb = root_.get()->GetBounds();
	draw_list->AddRectFilled(
		ImVec2(aabb.Minimum().x, aabb.Minimum().y),
		ImVec2(aabb.Maximum().x, aabb.Maximum().y),
		ImColor(0, 0, 0, 200)
	);
	*/
	root_->Draw(drawCollider, drawAABB, drawNodes);
}
#endif // _DEBUG

unsigned Quadtree::GetTotalObjects() noexcept
{
	return totalObjects_;
}


/*****************************************************************************/
/*							 NODE IMPLEMENTATION							 */
/*****************************************************************************/
/*****************************************************************************/
/*                            PUBLIC FUNCTIONS                               */
/*****************************************************************************/
bool Quadtree::Node::Insert(_In_ GameObject* object)
{
	Quadtree::Node* node = GetNodeForInsertion(object->GetAABB());

	if (node == this)
	{
		objects_.emplace_front(object);
		tree_->totalObjects_++;
		return true;
	}
	else
	{
		node->Insert(object);
	}

	return false;
}

bool Quadtree::Node::Remove(_In_ GameObject* object)
{
	Quadtree::Node* node = GetNodeForInsertion(object->GetAABB());

	if (node == this)
	{
		auto objItr = objects_.begin();
		while (objItr != objects_.end())
		{
			if (*object == *(*objItr))
			{
				objects_.remove((*objItr));
				tree_->totalObjects_--;

				if (parent_ != nullptr)
					parent_->EvaluateChildren();

				return true;
			}
			objItr++;
		}
	}
	else
	{
		node->Remove(object);
	}

	return false;
}

void Quadtree::Node::GetCollisionCandidates(_In_ GameObject* object, _Inout_ std::vector<GameObject*>& collisionCandidates) noexcept
{
	std::vector<GameObject*> potentialOverlaps;
	Search(object, potentialOverlaps);


	auto otherItr = potentialOverlaps.begin();
	while (otherItr != potentialOverlaps.end())
	{
		if (*object == *(*otherItr))
		{
			otherItr++;
			continue;
		}

		if ((*otherItr)->GetAABB().Overlaps(object->GetAABB()))
		{
			collisionCandidates.push_back(*otherItr);
		}

		/*
		for (auto& colItr : object->GetComponents(ComponentType::Collider))
		{
			auto col = static_cast<ColliderComponent*>(&colItr.get());

			for (auto& otherColItr : (*otherItr)->GetComponents(ComponentType::Collider))
			{
				auto otherCol = static_cast<ColliderComponent*>(&otherColItr.get());

				DirectX::SimpleMath::Vector2 colNorm, colDisp, colPoint;
				if (col->CollidesWith(*otherCol, colNorm, colDisp, colPoint))
				{
					collisionManager.AddCollision(object, *otherItr, col, otherCol, colNorm, colDisp, colPoint);
				}
			}
		}
		*/

		otherItr++;
	}
}

const AABB& Quadtree::Node::GetBounds() const noexcept
{
	return bounds_;
}

void Quadtree::Node::SetBounds(const AABB& bounds) noexcept
{
	using DirectX::SimpleMath::Vector2;
	bounds_ = bounds;
	/*
	if (children_[0] != nullptr)
	{
		const Vector2 center = bounds_.Center();

		children_[0]->SetBounds(AABB(bounds_.Minimum().x, bounds_.Minimum().y, center.x, center.y));

		children_[1]->SetBounds(AABB(center.x, bounds_.Minimum().y, bounds_.Maximum().x, center.y));

		children_[2]->SetBounds(AABB(bounds_.Minimum().x, center.y, center.x, bounds_.Maximum().y));

		children_[3]->SetBounds(AABB(center.x, center.y, bounds_.Maximum().x, bounds_.Maximum().y));
	}
	*/
}

void Quadtree::Node::Clear()
{
	tree_->totalObjects_ -= (unsigned)objects_.size();
	objects_.clear();

	if (children_[0] != nullptr)
	{
		for (auto& c : children_)
		{
			c->Clear();
			c.reset();
		}
	}
}

#ifdef _DEBUG
static std::array<DirectX::SimpleMath::Vector3, 10> colors =
{
	DirectX::SimpleMath::Vector3(1.0f, 0.0f, 0.0f),
	DirectX::SimpleMath::Vector3(0.0f, 1.0f, 0.0f),
	DirectX::SimpleMath::Vector3(0.0f, 0.0f, 1.0f),
	DirectX::SimpleMath::Vector3(0.5f, 0.0f, 0.0f),
	DirectX::SimpleMath::Vector3(0.0f, 0.5f, 0.0f),
	DirectX::SimpleMath::Vector3(0.0f, 0.0f, 0.5f),
	DirectX::SimpleMath::Vector3(0.5f, 0.0f, 1.0f),
	DirectX::SimpleMath::Vector3(1.0f, 1.0f, 0.0f),
	DirectX::SimpleMath::Vector3(0.0f, 1.0f, 0.5f),
	DirectX::SimpleMath::Vector3(1.0f, 0.0f, 0.5f),
};

void Quadtree::Node::Draw(bool drawCollider, bool drawAABB, bool drawNodes)
{
	float invZoom = 0.5f / Camera::Instance().GetZoom();

	auto& draw = DebugTools::Primary().Draw();
	if (drawNodes)
	{
		draw.LineBox(bounds_.Minimum(), bounds_.Maximum(), colors[depth_ % 10], invZoom);
	}

	if (children_[0] != nullptr)
	{
		for (auto& c : children_)
		{
			c->Draw(drawCollider, drawAABB, drawNodes);
		}
	}

	if (drawCollider || drawAABB) {
		for (auto object : objects_)
		{
			if (drawCollider)
			{
				for (auto& c : object->GetComponents(ComponentType::Collider))
				{
					auto& col = dynamic_cast<ColliderComponent&>(c.get());
					col.DrawCollider();
				}
			}

			if (drawAABB)
			{
				object->GetAABB().Draw();
			}
		}
	}

}
#endif // _DEBUG

/*****************************************************************************/
/*                            PRIVATE FUNCTIONS                              */
/*****************************************************************************/
void Quadtree::Node::Search(_In_ GameObject* object, _Inout_ std::vector<GameObject*>& potentialCollisions) noexcept
{
	potentialCollisions.insert(potentialCollisions.end(), objects_.begin(), objects_.end());

	Node* node = GetNodeForSearch(object->GetAABB());

	if (node != this)
	{
		node->Search(object, potentialCollisions);
	}
	else
	{
		if (children_[0] != nullptr)
		{
			for (auto& c : children_)
			{
				c->Search(object, potentialCollisions);
			}
		}
	}

}

void Quadtree::Node::Branch()
{
	using DirectX::SimpleMath::Vector2;
	const Vector2 center = bounds_.Center();

	children_[0] = std::make_shared<Node>(depth_ + 1,
		AABB(bounds_.Minimum().x, bounds_.Minimum().y, center.x, center.y),
		this, tree_);

	children_[1] = std::make_shared<Node>(depth_ + 1,
		AABB(center.x, bounds_.Minimum().y, bounds_.Maximum().x, center.y),
		this, tree_);

	children_[2] = std::make_shared<Node>(depth_ + 1,
		AABB(bounds_.Minimum().x, center.y, center.x, bounds_.Maximum().y),
		this, tree_);

	children_[3] = std::make_shared<Node>(depth_ + 1,
		AABB(center.x, center.y, bounds_.Maximum().x, bounds_.Maximum().y),
		this, tree_);

	auto o = objects_.begin();
	while (o != objects_.end())
	{
		Quadtree::Node* node = GetNodeForInsertion((*o)->GetAABB());
		if (node != this)
		{
			node->Insert(*o);
			o = objects_.erase(o);
			tree_->totalObjects_--;
		}
		else
		{
			o++;
		}
	}
}

void Quadtree::Node::EvaluateChildren()
{
	if (children_.at(0) == nullptr)
	{
		return;
	}

	const unsigned objectCount = GetObjectCountInNode();

	if (objectCount <= tree_->maxObjects_)
	{
		if (objects_.size() < objectCount)
		{
			for (auto& c : children_)
			{
				for (auto o : c.get()->objects_)
				{
					objects_.emplace_back(o);
				}
			}
		}
		children_.at(0).reset();
		children_.at(1).reset();
		children_.at(2).reset();
		children_.at(3).reset();
	}
	else
	{
		children_.at(0).get()->EvaluateChildren();
		children_.at(1).get()->EvaluateChildren();
		children_.at(2).get()->EvaluateChildren();
		children_.at(3).get()->EvaluateChildren();
	}
}

unsigned Quadtree::Node::GetObjectCountInNode()
{
	unsigned objectCount = (unsigned)objects_.size();
	if (children_.at(0))
	{
		objectCount += children_.at(0).get()->GetObjectCountInNode();
		objectCount += children_.at(1).get()->GetObjectCountInNode();
		objectCount += children_.at(2).get()->GetObjectCountInNode();
		objectCount += children_.at(3).get()->GetObjectCountInNode();
	}
	return objectCount;
}

Quadtree::Node* Quadtree::Node::GetNodeForInsertion(_In_ const AABB& objectBounds)
{
	using DirectX::SimpleMath::Vector2;

	if ((children_[0] == nullptr && objects_.size() < tree_->maxObjects_) || depth_ > tree_->maxDepth_)
		return this;

	const Vector2 center = bounds_.Center();

	const bool north = objectBounds.Minimum().y < center.y&& objectBounds.Maximum().y < center.y;
	const bool south = objectBounds.Minimum().y > center.y;
	const bool west = objectBounds.Minimum().x < center.x&& objectBounds.Maximum().x < center.x;
	const bool east = objectBounds.Minimum().x > center.x;
	if (east)
	{
		if (north)
		{
			if (children_[1] == nullptr) Branch();
			return children_[1].get()->GetNodeForInsertion(objectBounds);
		}
		else if (south)
		{
			if (children_[3] == nullptr) Branch();
			return children_[3].get()->GetNodeForInsertion(objectBounds);
		}
	}
	else if (west)
	{
		if (north)
		{
			if (children_[0] == nullptr) Branch();
			return children_[0].get()->GetNodeForInsertion(objectBounds);
		}
		else if (south)
		{
			if (children_[2] == nullptr) Branch();
			return children_[2].get()->GetNodeForInsertion(objectBounds);
		}
	}

	return this;
}

Quadtree::Node* Quadtree::Node::GetNodeForSearch(_In_ const AABB& objectBounds) noexcept
{
	using DirectX::SimpleMath::Vector2;
	const Vector2 center = bounds_.Center();

	const bool north = objectBounds.Minimum().y < center.y&& objectBounds.Maximum().y < center.y;
	const bool south = objectBounds.Minimum().y > center.y;
	const bool west = objectBounds.Minimum().x < center.x&& objectBounds.Maximum().x < center.x;
	const bool east = objectBounds.Minimum().x > center.x;

	if (children_[0] == nullptr)
		return this;

	if (east)
	{
		if (north)
		{
			return children_[1].get();
		}
		else if (south)
		{
			return children_[3].get();
		}
	}
	else if (west)
	{
		if (north)
		{
			return children_[0].get();
		}
		else if (south)
		{
			return children_[2].get();
		}
	}

	return this;
}

