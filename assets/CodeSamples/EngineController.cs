using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;
using TMPro;

public class EngineController : MonoBehaviour
{

    public float MaxAcceleration = 100f; // maximum torque the motor can apply to wheel
    public float MaxBrake = 80f;
    public AnimationCurve SteeringCurve;
    public AnimationCurve SidewaysStiffCurve;
    public AnimationCurve ForwardStiffCurve;

    [Header("Camera Settings")]
    public GameObject CinemachineController;
    public GameObject CameraTarget;
    public Camera PlayerCamera;


    [Header("Axle Information")]
    public TMP_Text DebugText;

    //All Gathered from the Player Input
    private float acceleration = 0f;
    private float brake = 0f;
    private float steering = 0f;
    private Vector2 lookAt;
    private string currentControlScheme = "Gamepad";
    private PlayerInput playerInput = null;

    private Rigidbody body;

    [Header("Axel Wheel Information")]
    public List<AxleInfo> AxleInfos; // the information about each individual axle
    public float MaxSteeringAngle = 30f;

    public float SidewaysStiffnessNormal = 30f;
    public float WheelSidewaysStiffnessDrift = 0.5f;

    private KeepUpright keepUpright;
    private bool disableKeepUpright = true;

    private float targetStiffnessMultiplier;
    private float stiffnessMultiplier;

    //instantiate audio
    private FMOD.Studio.EventInstance TrainAudio;
    private int lastcollision = 0;


    public void Start()
    {
        targetStiffnessMultiplier = SidewaysStiffnessNormal;
        stiffnessMultiplier = SidewaysStiffnessNormal;
        body = GetComponent<Rigidbody>();
        playerInput = GetComponent<PlayerInput>();
        keepUpright = GetComponent<KeepUpright>();

        //start audio
        TrainAudio = FMODUnity.RuntimeManager.CreateInstance("event:/Train Shit/2D/TrainNoise");
        TrainAudio.start();
        TrainAudio.release();

        GetComponent<PlayerInput>().enabled = false;
        GetComponent<PlayerInput>().enabled = true;
    }

    private void UpdateSteering(AxleInfo axle)
    {
        if (axle.steering == true)
        {
            axle.leftWheel.steerAngle = steering * (2 - stiffnessMultiplier);
            axle.rightWheel.steerAngle = steering * (2 - stiffnessMultiplier);
        }

    }

    private void UpdateAcceleration(AxleInfo axle)
    {
        if (axle.motor == true)
        {
            axle.leftWheel.motorTorque = acceleration;
            axle.rightWheel.motorTorque = acceleration;
        }
    }

    private void UpdateAudio()
    {
        FMODUnity.RuntimeManager.StudioSystem.setParameterByName("Train_Accel", acceleration);
        FMODUnity.RuntimeManager.StudioSystem.setParameterByName("Train_Speed", body.velocity.magnitude);
        lastcollision++;
        
    }

    private void UpdateBreak(AxleInfo axle)
    {
        if (acceleration <= 0f && Vector3.Dot(body.velocity, transform.forward) < 0)
        {
            axle.leftWheel.motorTorque = -brake;
            axle.rightWheel.motorTorque = -brake;
            axle.leftWheel.brakeTorque = 0;
            axle.rightWheel.brakeTorque = 0;
        }
        else
        {
            axle.leftWheel.brakeTorque = brake;
            axle.rightWheel.brakeTorque = brake;
        }
    }

    public void FixedUpdate()
    {
        DebugText.text = "Velocity: " + body.velocity.magnitude.ToString() + "\n";

        if (currentControlScheme.CompareTo("Gamepad") == 0)
        {
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = false;
        }
        else if (currentControlScheme.CompareTo("Keyboard&Mouse") == 0)
        {
            Cursor.lockState = CursorLockMode.Locked;
            Cursor.visible = false;
        }

        disableKeepUpright = false;

        //axil information
        foreach (AxleInfo axleInfo in AxleInfos)
        {
            WheelCollider wl = axleInfo.leftWheel.GetComponent<WheelCollider>();
            WheelCollider wr = axleInfo.rightWheel.GetComponent<WheelCollider>();

            WheelHit hit;
            if (wl.GetGroundHit(out hit))
            {
                //DebugText.text += wl.name + ": " + (hit.sidewaysSlip / wl.sidewaysFriction.extremumSlip).ToString() + "\n";
                disableKeepUpright = false;
            }
            if (wr.GetGroundHit(out hit))
            {
                //DebugText.text += wr.name + ": " + (hit.sidewaysSlip / wr.sidewaysFriction.extremumSlip).ToString() + "\n";
                disableKeepUpright = false;
            }

            FMODUnity.RuntimeManager.StudioSystem.setParameterByName("Train_Skid", Mathf.Abs(hit.sidewaysSlip));

            UpdateAcceleration(axleInfo);
            UpdateSteering(axleInfo);
            UpdateBreak(axleInfo);

            stiffnessMultiplier = Mathf.Lerp(stiffnessMultiplier, targetStiffnessMultiplier, Time.fixedDeltaTime * 2);
            WheelFrictionCurve frictionL = wl.sidewaysFriction;
            frictionL.stiffness = stiffnessMultiplier * SidewaysStiffCurve.Evaluate(body.velocity.magnitude);
            wl.sidewaysFriction = frictionL;
            //Debug.Log(wl.sidewaysFriction.stiffness);

            WheelFrictionCurve frictionR = wr.sidewaysFriction;
            frictionR.stiffness = frictionL.stiffness;
            wr.sidewaysFriction = frictionR;

            var ffL = wl.forwardFriction;
            ffL.stiffness = stiffnessMultiplier * ForwardStiffCurve.Evaluate(body.velocity.magnitude);
            wl.forwardFriction = ffL;
            var ffR = wr.forwardFriction;
            ffR.stiffness = ffL.stiffness;
            wr.forwardFriction = ffR;

            //audio
            UpdateAudio();
            UpdateAudio();
        }

        keepUpright.enabled = !disableKeepUpright;

    }

    public void OnCollisionStay(Collision collision)
    {
        disableKeepUpright = false;
        keepUpright.enabled = !disableKeepUpright;

        //audio
        FMOD.Studio.EventInstance CollisionAudio;

        if (lastcollision >= 500)
        {
            CollisionAudio = FMODUnity.RuntimeManager.CreateInstance("event:/Train Shit/2D/TrainCollision");
            CollisionAudio.setParameterByName("TrainImpactSpeed", body.velocity.magnitude);
            CollisionAudio.start();
            CollisionAudio.release();
            lastcollision = 0;
        }

    }


    #region Messages from Player Input

    public void OnDrift(InputValue driftInput)
    {
        if (driftInput.Get<float>() > 0f)
        {
            targetStiffnessMultiplier = WheelSidewaysStiffnessDrift;

            foreach (AxleInfo axleInfo in AxleInfos)
            {
                WheelCollider wl = axleInfo.leftWheel.GetComponent<WheelCollider>();
                WheelCollider wr = axleInfo.rightWheel.GetComponent<WheelCollider>();
                WheelFrictionCurve frictionL = wl.sidewaysFriction;
                frictionL.stiffness = WheelSidewaysStiffnessDrift;
                wl.sidewaysFriction = frictionL;

                WheelFrictionCurve frictionR = wr.sidewaysFriction;
                frictionR.stiffness = frictionL.stiffness;
                wr.sidewaysFriction = frictionR;
            }
        }
        else
        {
            targetStiffnessMultiplier = SidewaysStiffnessNormal;
        }

    }

    public void OnSteer(InputValue steeringInput)
    {
        // todo better keyboard steering
        steering = steeringInput.Get<float>() * SteeringCurve.Evaluate(body.velocity.magnitude);
    }

    public void OnAccelerate(InputValue accelerateInput)
    {
        acceleration = accelerateInput.Get<float>() * MaxAcceleration;
    }

    public void OnBrake(InputValue brakeInput)
    {
        brake = brakeInput.Get<float>() * MaxBrake;
    }

    public void OnLook(InputValue lookInput)
    {
        lookAt = lookInput.Get<Vector2>();
    }

    public void OnControlsChanged()
    {
        if (playerInput == null)
        {
            playerInput = GetComponent<PlayerInput>();
        }

        currentControlScheme = playerInput.currentControlScheme;
    }

    #endregion

}

[System.Serializable]
public class AxleInfo
{
    public WheelCollider leftWheel;
    public WheelCollider rightWheel;
    public bool motor; // is this wheel attached to motor?
    public bool steering; // does this wheel apply steer angle?
}
