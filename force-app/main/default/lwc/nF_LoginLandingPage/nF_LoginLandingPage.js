import { LightningElement, track } from 'lwc';

export default class NFLoginLandingPage extends LightningElement {
    @track email = '';
    @track password = '';
    @track rememberMe = false;
    @track showPassword = false;

    get passwordInputType() {
        return this.showPassword ? 'text' : 'password';
    }

    get eyeAriaLabel() {
        return this.showPassword ? 'Hide password' : 'Show password';
    }

    handleEmailChange(e)    { this.email = e.target.value; }
    handlePasswordChange(e) { this.password = e.target.value; }
    handleRememberChange(e) { this.rememberMe = e.target.checked; }
    togglePassword()        { this.showPassword = !this.showPassword; }

    handleSignIn(e) {
        e.preventDefault();
        this.dispatchEvent(new CustomEvent('signin', {
            detail: { email: this.email, password: this.password, rememberMe: this.rememberMe }
        }));
    }

    handleGoogle(e) {
        e.preventDefault();
        this.dispatchEvent(new CustomEvent('googlesignin'));
    }

    handleForgotPassword(e) {
        e.preventDefault();
        this.dispatchEvent(new CustomEvent('forgotpassword'));
    }

    handleSignUp(e) {
        e.preventDefault();
        this.dispatchEvent(new CustomEvent('signup'));
    }

    handleHome(e)    { e.preventDefault(); this.dispatchEvent(new CustomEvent('navhome')); }
    handleContact(e) { e.preventDefault(); this.dispatchEvent(new CustomEvent('navcontact')); }
    handleDemo(e)    { e.preventDefault(); this.dispatchEvent(new CustomEvent('navdemo')); }
}
