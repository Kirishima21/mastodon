import React from 'react';
import Button from '../../../components/button';

export default class CustomEmojiOekaki extends React.PureComponent {

  onClick(e) {
    e.preventDefault();
    window.open('https://mamemomonga.github.io/mastodon-custom-emoji-oekaki/#kirishima.cloud');
  }

  render () {
    return (
      <div className='emoji-oekaki'>
        <Button text='☆絵文字でお絵かき☆' onClick={this.onClick} className='custom-emoji-oekaki' />
      </div>
    );
  }
}
